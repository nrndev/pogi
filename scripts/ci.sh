#!/bin/sh
# Runs the same checks as CI. Every CI job calls this script, so what passes here passes there.
#
#   scripts/ci.sh [step ...]     no arguments runs: coverage fmt vet build cross release-check lint workflows test all
#
# Steps:
#   fmt              gofmt finds nothing to change
#   vet              go vet ./...
#   build            builds ./cmd/pogi and runs "pogi version"
#   cross [os/arch ...]  builds ./cmd/pogi for the given platforms, default all six release ones (CGO off)
#   release-check    goreleaser check (the release config)
#   lint [group]     golangci-lint (config: .golangci.yml): every package, or one test group's, built with -race
#   workflows        actionlint and zizmor on .github/workflows
#   coverage         every Go package is in exactly one test group
#   groups           prints the test group names, one per line
#   test <group>     the race tests of one group (Docker off, 8 minute limit per package); "all" runs every group
#   conformance [block ...]   scripts/conformance.sh (Terraform and CDK against a fresh pogi)
#   security [tool ...]       scripts/security-scan.sh
#   notes <version>  prints that version's CHANGELOG.md section, the release page notes (links made absolute)
#   e2e [playwright args]   the console's browser tests (test/e2e)
#   gate             the full pre-release gate: go test -race ./... with Docker ON, scripts/conformance.sh, then e2e
#
# test, conformance, security and e2e take the rest of the arguments, so put them last.
#
# A missing tool is skipped with a hint on your machine, and fails the step when CI=true (GitHub sets it).
# When GITHUB_STEP_SUMMARY is set, "test" also writes JUnit XML and JSON to test-results/ and adds a table
# of the totals and the failed tests to the job summary.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

# Pinned tools that run through "go run". Raise them on purpose, not by accident.
gotestsum_pkg=gotest.tools/gotestsum@c4a0df2e75a225d979a444342dd3db752b53619f # v1.13.0
actionlint_pkg=github.com/rhysd/actionlint/cmd/actionlint@914e7df21a07ef503a81201c76d2b11c789d3fca # v1.7.12

# The platforms "cross" builds, the same six as the release.
platforms="linux/amd64 linux/arm64 darwin/amd64 darwin/arm64 windows/amd64 windows/arm64"

# --- test groups -------------------------------------------------------------
# The only place the groups are defined. Each group is a pattern on the package path (it starts with "./",
# the module root is "./."). Core, one group for GCP, and the big clouds split by the first letter of the
# service folder. The letters are set by measured cold compile time (4 cores), so no group takes much more
# than 1.3 times another in its cloud: aws about 79 / 100 / 82 s, azure 62 / 77 s, gcp 99 s, core 66 s. Move a
# boundary when a service is added and one group runs long. CI runs the groups side by side with Docker off.
# "coverage" fails when a package is in no group or in two, so a new package makes CI fail until it is put in one.
test_groups="core aws-a-f aws-g-m aws-n-z azure-a-c azure-d-z gcp"

group_pattern() {
  case $1 in
    aws-a-f)   echo 'internal/aws/[a-f]' ;;
    aws-g-m)   echo 'internal/aws/[g-m]' ;;
    aws-n-z)   echo 'internal/aws/[n-z]' ;;
    azure-a-c) echo 'internal/azure/[a-c]' ;;
    azure-d-z) echo 'internal/azure/[d-z]' ;;
    gcp)   echo 'internal/gcp(/|$)' ;;
    core)  echo '(\.|cmd|scripts|test|internal/(aimodel|amqp|awstest|config|core|cost|docker|duckdb|mcp|seed|terraform|tui|web))(/|$)' ;;
    *)     return 1 ;;
  esac
}

# --- helpers -----------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }
die() { echo "ci.sh: $*" >&2; exit 1; }

# need <program> [brew name]: true if the program exists. If not: CI fails, a laptop skips with a hint.
need() {
  have "$1" && return 0
  [ "${CI:-}" = true ] && die "$1 is not installed"
  echo "skipped: install $1 (brew install ${2:-$1})"
  return 1
}

# Prints a warning when the local tool is not the version the workflows pin.
# warn_version <tool> <local version> <pinned version>
warn_version() {
  [ -n "$3" ] && [ "$2" != "$3" ] && echo "warning: $1 is $2 here, CI pins $3" >&2
  return 0
}

# The version preflight.yml pins for a tool: a line with "version: v2.18.3" or "zizmor==1.30.1" and "# pinned <tool>".
pinned() { sed -nE "s/.*(version: v|==)([0-9][0-9.]*) # pinned $1.*/\2/p" .github/workflows/preflight.yml | head -1; }

# Every package of the module as ./path, the module root as ./.
list_pkgs() {
  mod=$(go list -m)
  go list ./... | sed -e "s#^$mod\$#./.#" -e "s#^$mod/#./#"
}

# group_pkgs <group>: the group's packages, one word each.
group_pkgs() {
  pat=$(group_pattern "$1") || die "unknown group: $1 (choose from: $test_groups)"
  pkgs=$(list_pkgs | grep -E "^\\./($pat)" || true)
  [ -n "$pkgs" ] || die "group $1 has no package"
  echo "$pkgs"
}

# --- steps -------------------------------------------------------------------

step_fmt() {
  out=$(gofmt -l .)
  [ -z "$out" ] || { echo "gofmt would change:"; echo "$out"; return 1; }
  echo "fmt: ok"
}

step_vet() { go vet ./...; }

step_build() {
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  go build -o "$tmp/pogi" ./cmd/pogi
  "$tmp/pogi" version
}

# step_cross [os/arch ...]: CI runs one platform per job, in parallel.
step_cross() {
  [ $# -gt 0 ] || set -- $platforms
  for p in "$@"; do
    echo "build $p"
    CGO_ENABLED=0 GOOS=${p%/*} GOARCH=${p#*/} go build -trimpath -o /dev/null ./cmd/pogi
  done
}

step_release_check() {
  need goreleaser || return 0
  warn_version goreleaser "$(goreleaser --version | sed -n 's/^GitVersion: *//p')" "$(pinned goreleaser)"
  goreleaser check
}

# step_lint [group]: with a group, only that group's packages, built with -race like step_test, so the test job
# that follows reuses what lint compiled. Without one, every package (a release and the gate use that).
step_lint() {
  need golangci-lint || return 0
  warn_version golangci-lint "$(golangci-lint --version | sed -n 's/^golangci-lint has version \([0-9.]*\).*/\1/p')" "$(pinned golangci-lint)"
  if [ $# -eq 0 ]; then golangci-lint run ./...; return; fi
  pkgs=$(group_pkgs "$1")
  # shellcheck disable=SC2086
  GOFLAGS=-race golangci-lint run $pkgs
}

step_workflows() {
  if have actionlint; then actionlint; else go run "$actionlint_pkg"; fi
  need zizmor || return 0
  warn_version zizmor "$(zizmor --version | sed 's/^zizmor //')" "$(pinned zizmor)"
  # Some audits ask GitHub's API and need a token. Without one they are skipped.
  online=
  [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ] || online=--no-online-audits
  zizmor $online .github/workflows
}

step_groups() { for g in $test_groups; do echo "$g"; done; }

# Every package is in exactly one group, every group has a package, and every example folder has a conformance job.
step_coverage() {
  pkgs=$(list_pkgs)
  problems=$(echo "$pkgs" | while read -r p; do
    n=0
    for g in $test_groups; do
      echo "$p" | grep -Eq "^\\./($(group_pattern "$g"))" && n=$((n + 1))
    done
    [ $n = 1 ] || echo "$p is in $n test groups (it must be in exactly one: see group_pattern in scripts/ci.sh)"
  done)
  for g in $test_groups; do
    echo "$pkgs" | grep -Eq "^\\./($(group_pattern "$g"))" || problems="$problems
group $g matches no package"
  done
  # Every Thin example folder is a conformance block, and a preflight matrix entry must run it (or its cloud's
  # "-thin" block), or CI would skip it without a word.
  for dir in examples/terraform-*-thin-*/; do
    name=$(basename "$dir"); cloud=${name#terraform-}; cloud=${cloud%%-thin-*}; group=${name#*-thin-}
    [ "$cloud" = azure ] && cloud=azurerm
    grep -Eq "^ +- \"(.* )?($cloud-$group|$cloud-thin)( .*)?\"$" .github/workflows/preflight.yml ||
      problems="$problems
$name is in no conformance job: add $cloud-$group to the blocks matrix in .github/workflows/preflight.yml"
  done
  [ -z "$problems" ] || { echo "$problems" >&2; return 1; }
  echo "coverage: $(echo "$pkgs" | wc -l | tr -d ' ') packages, each in one of $(echo "$test_groups" | wc -w | tr -d ' ') groups"
}

# step_test <group>|all
step_test() {
  [ $# -ge 1 ] || die "test needs a group ($test_groups) or all"
  if [ "$1" = all ]; then
    for g in $test_groups; do echo "== $g"; step_test "$g"; done
    return 0
  fi
  g=$1
  pkgs=$(group_pkgs "$g")
  set -- --format pkgname-and-test-fails --format-hide-empty-pkg --hide-summary skipped
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    need jq || return 1
    set -- "$@" --jsonfile "test-results/$g.json" --junitfile "test-results/$g.xml" \
      --post-run-command "sh $root/scripts/ci.sh report $g"
  fi
  # Docker is off: tests that need it skip themselves. They run in "gate" on a developer machine.
  # $pkgs is left unquoted on purpose: one word per package.
  # shellcheck disable=SC2086
  DOCKER_HOST=unix:///nonexistent/docker.sock go run "$gotestsum_pkg" "$@" -- -race -count=1 -timeout 8m $pkgs
}

# Called by gotestsum after the run (not by hand): adds the totals and the failed tests to the job summary,
# and one annotation per failed test. It never fails, so it cannot hide the test result.
step_report() {
  g=${1:-tests}
  json=${GOTESTSUM_JSONFILE:-}
  [ -s "$json" ] && [ -n "${GITHUB_STEP_SUMMARY:-}" ] && have jq || return 0
  mod=$(go list -m)
  # The failed tests that have no failing subtest, each with its output.
  # shellcheck disable=SC2016 # the jq programs are single-quoted on purpose
  prelude='
    def short: sub("^" + $mod + "/?"; "") | if . == "" then "." else . end;
    def tail($n): rtrimstr("\n") | split("\n") | .[-$n:] | join("\n");
    (reduce (.[] | select(.Action == "output")) as $e ({}; .[$e.Package + "|" + ($e.Test // "")] += $e.Output)) as $out
    | [.[] | select(.Test != null and .Action == "fail")] as $f
    | ($f | map(.Package + "|" + .Test)) as $names
    | ($f | map(select((.Package + "|" + .Test) as $k | $names | any(startswith($k + "/")) | not))) as $leaves
    | ([.[] | select(.Test == null and .Action == "fail") | .Package] - ($leaves | map(.Package))) as $badpkgs
  '
  # shellcheck disable=SC2016
  summary="$prelude"'
    | "### Tests: \($group)", "",
    "| tests | failed | skipped | errors | time |", "|---:|---:|---:|---:|---:|",
    "| \($total) | \($failed) | \($skipped) | \($errors) | \($time) |", "",
    ($leaves[] | "<details><summary>FAIL \(.Test) (\(.Package | short))</summary>\n\n```\n\($out[.Package + "|" + .Test] // "" | tail(40))\n```\n\n</details>\n"),
    ($badpkgs[] | "<details><summary>FAIL package \(. | short)</summary>\n\n```\n\($out[. + "|"] // "" | tail(40))\n```\n\n</details>\n")
  '
  jq -rs --arg mod "$mod" --arg group "$g" --arg total "${TESTS_TOTAL:-?}" --arg failed "${TESTS_FAILED:-?}" \
    --arg skipped "${TESTS_SKIPPED:-?}" --arg errors "${TESTS_ERRORS:-?}" --arg time "${GOTESTSUM_ELAPSED:-?}" \
    "$summary" "$json" >>"$GITHUB_STEP_SUMMARY" || true
  [ -n "${GITHUB_ACTIONS:-}" ] || return 0
  # An annotation points at the first "file.go:line:" line of the test's output, when there is one.
  # shellcheck disable=SC2016
  annotations="$prelude"'
    | ($leaves[] | . as $l | ($out[.Package + "|" + .Test] // "") as $o
      | ([$o | split("\n")[] | capture("^\\s+(?<f>[A-Za-z0-9_.-]+\\.go):(?<l>[0-9]+): (?<m>.*)$")] | first) as $h
      | ($l.Package | short) as $dir
      | ("FAIL " + $l.Test | gsub(","; "%2C") | gsub(":"; "%3A")) as $title
      | if $h then "::error file=\($dir)/\($h.f),line=\($h.l),title=\($title)::\($h.m | gsub("%"; "%25") | gsub("\r"; "%0D"))"
        else "::error title=\($title)::failed in \($l.Package | short)" end),
    ($badpkgs[] | "::error title=FAIL package::\(. | short) failed (build error or panic): see the job summary")
  '
  jq -rs --arg mod "$mod" "$annotations" "$json" || true
}

step_conformance() {
  # Terraform keeps its provider downloads here, between runs (only the blocks of one job share it).
  [ -z "${TF_PLUGIN_CACHE_DIR:-}" ] || mkdir -p "$TF_PLUGIN_CACHE_DIR"
  sh scripts/conformance.sh "$@"
}

step_security() {
  rc=0
  sh scripts/security-scan.sh "$@" || rc=$?
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -f scan-results/SUMMARY.md ]; then
    { echo "### Security scan"; echo; cat scan-results/SUMMARY.md; } >>"$GITHUB_STEP_SUMMARY"
  fi
  return $rc
}

# The full local gate before a release. Docker is ON here, so the container-backed tests run.
# step_notes <version>: the "## [x.y.z]" section of CHANGELOG.md, without its heading. Relative links point
# at the tagged tree on GitHub, since the release page has no files next to it. Fails when the section is missing.
step_notes() {
  v=${1:?usage: scripts/ci.sh notes <version>}; v=${v#v}
  base=${v%%-*} # a pre-release such as 0.2.0-rc.1 uses the section of the version it leads to
  out=$(awk -v h="## [$base]" 'index($0, h) == 1 { on = 1; next } on && /^## \[/ { exit } on && !/^\[[^]]*\]: /' CHANGELOG.md |
    sed "s#](docs/#](https://github.com/nrndev/pogi/blob/v$v/docs/#g")
  [ -n "$(printf '%s' "$out" | tr -d '[:space:]')" ] || die "CHANGELOG.md has no section for $base"
  [ "$base" = "$v" ] || printf 'A release candidate for v%s. Install it from this page: Homebrew, Scoop and the `latest` image stay on the last release.\n\n' "$base"
  printf '%s\n' "$out"
}

# Browser tests of the console against a real pogi (test/e2e, Playwright). Extra arguments go to "playwright test".
step_e2e() {
  need npm node || return 0
  (cd test/e2e && npm ci && npx playwright install chromium && npx playwright test "$@")
}

step_gate() {
  go test -race -count=1 ./...
  sh scripts/conformance.sh
  step_e2e
}

# --- run ---------------------------------------------------------------------

[ $# -gt 0 ] || set -- coverage fmt vet build cross release-check lint workflows test all
while [ $# -gt 0 ]; do
  s=$1; shift
  case $s in
    lint) # takes a group name when one follows
      if [ $# -gt 0 ] && group_pattern "$1" >/dev/null 2>&1; then step_lint "$1"; shift; else step_lint; fi ;;
    fmt|vet|build|workflows|coverage|groups|gate) "step_$s" ;;
    cross) # takes the os/arch arguments that follow it
      ps=""; while [ $# -gt 0 ] && case $1 in */*) true ;; *) false ;; esac; do ps="$ps $1"; shift; done
      step_cross $ps ;;
    release-check) step_release_check ;;
    report) step_report "$@"; exit 0 ;;
    test|conformance|security|e2e) "step_$s" "$@"; exit $? ;; # these take the rest of the arguments
    notes) step_notes "${1:-}"; exit $? ;;
    *) die "unknown step: $s (fmt vet build cross release-check lint workflows coverage groups test conformance security e2e notes gate)" ;;
  esac
done

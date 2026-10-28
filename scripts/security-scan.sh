#!/bin/sh
# Reruns the security checks on pogi. Anyone can run it.
#
#   scripts/security-scan.sh [tool ...]     no arguments runs every tool
#
# Tools:
#   vuln      known CVEs in modules the code really calls   (govulncheck)
#   gosec     Go code scan                                  (gosec)
#   semgrep   Go, JS, Dockerfile and workflow code scan     (Semgrep)
#   trivy     dependencies, secrets and misconfig in the tree (Trivy fs)
#   secrets   secrets in the git history                    (Gitleaks)
#   image     the Docker image                              (docker build, then Trivy image; IMAGE=ref scans that image instead)
#   dast      the running server, from outside              (OWASP ZAP; DAST_FULL=1 for the slow active scan)
#
# Each tool uses a program on your PATH when there is one, and a pinned Docker image when there is not.
# A tool with neither is reported as skipped and does not fail the run.
#
# Results go to scan-results/: one raw file per tool, and SUMMARY.md with one row per tool.
#
# EXIT STATUS. The script exits non-zero only when:
#   - Trivy finds a fixable HIGH or CRITICAL CVE (in the tree or the image),
#   - govulncheck finds a vulnerability that the code calls, or
#   - Trivy finds a secret in the tree.
# gosec, Semgrep, Gitleaks and ZAP only report. Their hits are expected: test fixtures and the emulator's
# sample keys look like problems to a scanner.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/scan-results
cd "$root"

# Pinned versions. Raise them on purpose, not by accident.
govulncheck_pkg=golang.org/x/vuln/cmd/govulncheck@v1.9.0
gosec_pkg=github.com/securego/gosec/v2/cmd/gosec@v2.29.0
semgrep_image=semgrep/semgrep:1.180.0
trivy_image=aquasec/trivy:0.76.0
gitleaks_image=zricethezav/gitleaks:v8.30.1
zap_image=zaproxy/zap-stable:2.17.0
trivy_cache=pogi-scan-trivy-cache
secret_config=scripts/security/trivy-secret.yaml

all="vuln gosec semgrep trivy secrets image dast"
tools=${*:-$all}
for t in $tools; do
  case " $all " in *" $t "*) ;; *) echo "unknown tool: $t (choose from: $all)" >&2; exit 2 ;; esac
done

mkdir -p "$out"
fail=0
net_made=0
built=0

# --- helpers -----------------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }
# Docker counts only when the daemon answers.
docker_ok() { have docker && docker info >/dev/null 2>&1; }
# Counts how many times a pattern appears in a file (0 if the file is missing).
count() { [ -f "$2" ] && grep -o "$1" "$2" | wc -l | tr -d ' ' || echo 0; }

# Starts a fresh SUMMARY.md. Rows are added by row().
printf '| tool | version or image | result | raw file |\n|---|---|---|---|\n' >"$out/SUMMARY.md"
row() { printf '| %s | %s | %s | %s |\n' "$1" "$2" "$3" "$4" >>"$out/SUMMARY.md"; echo "$1: $3"; }

# Removes only what this run created: the pogi container and the scan network.
cleanup() {
  docker rm -f pogi-scan >/dev/null 2>&1 || true
  [ "$net_made" = 1 ] && docker network rm pogi-scan-net >/dev/null 2>&1 || true
  [ "$built" = 1 ] && docker rmi pogi:scan >/dev/null 2>&1 || true
}
trap cleanup EXIT

# The image to scan. Unset: the one build_image makes. IMAGE=ghcr.io/nrndev/pogi:latest scans a published image,
# with no build (the weekly image-scan workflow does this).
image=${IMAGE:-pogi:scan}

# Builds the image once per run, so "image" and "dast" scan the same build.
build_image() {
  [ "$built" = 1 ] && return 0
  docker build -t pogi:scan "$root" >"$out/docker-build.log" 2>&1 || { echo "docker build failed, see $out/docker-build.log" >&2; return 1; }
  built=1
}

# Runs Trivy on the repo tree. Native Trivy if installed, else the pinned image with the repo mounted
# read-only. First argument: the output file name. The rest: extra Trivy options.
# The scan-results folder is skipped so earlier reports are not scanned.
trivy_fs() {
  name=$1; shift
  if have trivy; then
    trivy fs --skip-dirs scan-results --secret-config "$secret_config" -o "$out/$name" "$@" .
  else
    docker run --rm -v "$root:/src:ro" -v "$out:/out" -v "$trivy_cache:/root/.cache" -w /src "$trivy_image" \
      fs --skip-dirs scan-results --secret-config "$secret_config" -o "/out/$name" "$@" .
  fi
}

# Same for the built image. The Docker image needs the Docker socket to see pogi:scan.
trivy_image() {
  name=$1; shift
  if have trivy; then
    trivy image -o "$out/$name" "$@" "$image"
  else
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$out:/out" -v "$trivy_cache:/root/.cache" "$trivy_image" \
      image -o "/out/$name" "$@" "$image"
  fi
}

trivy_version() { if have trivy; then trivy --version | head -1; else echo "$trivy_image"; fi; }
trivy_can_run() { have trivy || docker_ok; }

# Counts findings by severity in a Trivy JSON report.
trivy_counts() {
  printf 'CRITICAL %s, HIGH %s, MEDIUM %s, LOW %s' \
    "$(count '"Severity": "CRITICAL"' "$1")" "$(count '"Severity": "HIGH"' "$1")" \
    "$(count '"Severity": "MEDIUM"' "$1")" "$(count '"Severity": "LOW"' "$1")"
}

# --- tools -------------------------------------------------------------------

# Known CVEs. govulncheck only reports a module bug when the code can reach it, and exits 3 then.
scan_vuln() {
  if have govulncheck; then cmd=govulncheck; ver=$(govulncheck -version 2>/dev/null | head -1 || true)
  elif have go; then cmd="go run $govulncheck_pkg"; ver=$govulncheck_pkg
  else row vuln - "skipped: install govulncheck or Go" -; return; fi
  rc=0
  $cmd ./... >"$out/govulncheck.txt" 2>&1 || rc=$?
  n=$(grep -c '^Vulnerability #' "$out/govulncheck.txt" || true)
  # govulncheck exits 3 for a called vulnerability, but "go run" turns that into 1. So go by the report.
  if [ "$n" -gt 0 ]; then
    row vuln "${ver:-govulncheck}" "FAIL: $n called vulnerabilities (a newer Go may clear the standard library ones)" govulncheck.txt; fail=1
    cat "$out/govulncheck.txt" >&2
  elif [ $rc != 0 ]; then
    row vuln "${ver:-govulncheck}" "error (exit $rc), see the file" govulncheck.txt
  else
    row vuln "${ver:-govulncheck}" "0 called vulnerabilities" govulncheck.txt
  fi
}

# Go code scan. Report only, so -no-fail. The summary counts findings by rule.
scan_gosec() {
  if have gosec; then cmd=gosec; ver=$(gosec -version 2>/dev/null | head -1 || true)
  elif have go; then cmd="go run $gosec_pkg"; ver=$gosec_pkg
  else row gosec - "skipped: install gosec or Go" -; return; fi
  rm -f "$out/gosec.json"
  $cmd -no-fail -quiet -fmt json -out "$out/gosec.json" ./... >"$out/gosec.log" 2>&1 || true
  if [ ! -s "$out/gosec.json" ]; then row gosec "${ver:-gosec}" "error, see gosec.log" gosec.log; return; fi
  n=$(count '"rule_id"' "$out/gosec.json")
  by=$(grep -o '"rule_id": *"G[0-9]*"' "$out/gosec.json" | grep -o 'G[0-9]*' | sort | uniq -c | awk '{printf "%s%s x%s", (NR>1?", ":""), $2, $1}')
  row gosec "${ver:-gosec}" "$n findings${by:+ ($by)}" gosec.json
}

# Code scan for Go, JS, Dockerfiles and workflows. Report only.
scan_semgrep() {
  cfg="--config p/golang --config p/javascript --config p/dockerfile --config p/github-actions"
  if have semgrep; then
    ver=$(semgrep --version 2>/dev/null | head -1 || true)
    # shellcheck disable=SC2086
    semgrep scan --metrics=off $cfg --json -o "$out/semgrep.json" . >"$out/semgrep.log" 2>&1 || true
  elif docker_ok; then
    ver=$semgrep_image
    # shellcheck disable=SC2086
    docker run --rm -v "$root:/src:ro" -v "$out:/out" -w /src "$semgrep_image" \
      semgrep scan --metrics=off $cfg --json -o /out/semgrep.json . >"$out/semgrep.log" 2>&1 || true
  else row semgrep - "skipped: install Semgrep or Docker" -; return; fi
  if [ ! -s "$out/semgrep.json" ]; then row semgrep "$ver" "error, see semgrep.log" semgrep.log; return; fi
  row semgrep "$ver" "$(count '"check_id"' "$out/semgrep.json") findings" semgrep.json
}

# Dependencies, secrets and misconfig in the tree. Two steps:
#   1. a full JSON report (all severities) for reading;
#   2. a gate run: fixable HIGH/CRITICAL CVEs, then any secret. Either one fails the run.
scan_trivy() {
  if ! trivy_can_run; then row trivy - "skipped: install Trivy or Docker" -; return; fi
  trivy_fs trivy-fs.json --scanners vuln,secret,misconfig --format json --quiet || true
  rc=0
  trivy_fs trivy-fs-gate-vuln.txt --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --quiet || rc=$?
  sc=0
  trivy_fs trivy-fs-gate-secret.txt --scanners secret --exit-code 1 --quiet || sc=$?
  res=$(trivy_counts "$out/trivy-fs.json")
  if [ $rc != 0 ] || [ $sc != 0 ]; then
    # The CVE table goes to the log, so a CI run shows which one failed. The secret gate is not printed: no
    # secret goes into a log.
    [ $rc != 0 ] && { res="$res; FAIL: fixable HIGH/CRITICAL CVE"; cat "$out/trivy-fs-gate-vuln.txt" >&2 || true; }
    [ $sc != 0 ] && res="$res; FAIL: secret found"
    fail=1
  fi
  row trivy "$(trivy_version)" "$res" trivy-fs.json
}

# Secrets in the git history.
scan_secrets() {
  if have gitleaks; then
    ver=$(gitleaks version 2>/dev/null | head -1 || true)
    gitleaks git --report-format json --report-path "$out/gitleaks.json" --exit-code 0 "$root" >"$out/gitleaks.log" 2>&1 || true
  elif docker_ok; then
    ver=$gitleaks_image
    # git refuses repos owned by another user, so tell it this mount is fine.
    docker run --rm -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=/repo \
      -v "$root:/repo:ro" -v "$out:/out" "$gitleaks_image" \
      git --report-format json --report-path /out/gitleaks.json --exit-code 0 /repo >"$out/gitleaks.log" 2>&1 || true
  else row secrets - "skipped: install Gitleaks or Docker" -; return; fi
  if [ ! -f "$out/gitleaks.json" ]; then row secrets "$ver" "error, see gitleaks.log" gitleaks.log; return; fi
  row secrets "$ver" "$(count '"RuleID"' "$out/gitleaks.json") findings" gitleaks.json
}

# The Docker image: build it (unless IMAGE is set), then scan its packages with Trivy. Writes a SARIF file of the
# fixable HIGH and CRITICAL findings too, for GitHub's Security tab.
scan_image() {
  if ! docker_ok; then row image - "skipped: install Docker" -; return; fi
  if ! trivy_can_run; then row image - "skipped: install Trivy or Docker" -; return; fi
  [ -n "${IMAGE:-}" ] || build_image || { row image docker "error: docker build failed" docker-build.log; return; }
  trivy_image trivy-image.json --scanners vuln --format json --quiet || true
  trivy_image trivy-image.sarif --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --format sarif --quiet || true
  rc=0
  trivy_image trivy-image-gate.txt --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --quiet || rc=$?
  res=$(trivy_counts "$out/trivy-image.json")
  if [ $rc != 0 ]; then res="$res; FAIL: fixable HIGH/CRITICAL CVE"; fail=1; cat "$out/trivy-image-gate.txt" >&2 || true; fi
  row image "$(trivy_version)" "$res" trivy-image.json
}

# The running server, scanned from outside by ZAP. pogi runs on a private Docker network with no
# published port, so nothing on this machine's network can reach it. Report only.
scan_dast() {
  if ! docker_ok; then row dast - "skipped: install Docker" -; return; fi
  build_image || { row dast docker "error: docker build failed" docker-build.log; return; }
  docker network create pogi-scan-net >/dev/null && net_made=1
  docker run -d --name pogi-scan --network pogi-scan-net pogi:scan >/dev/null
  # Wait up to 60 seconds for pogi to answer.
  i=0
  until docker exec pogi-scan pogi wait --timeout 1s --endpoint http://127.0.0.1:7644 >/dev/null 2>&1; do
    i=$((i + 1)); [ $i -lt 60 ] || { row dast "$zap_image" "error: pogi did not start" -; return; }
    sleep 1
  done
  # The ZAP container runs as another user, so the results folder must be writable by it.
  chmod a+w "$out"
  zap() { docker run --rm --network pogi-scan-net -v "$out:/zap/wrk:rw" "$zap_image" "$@" >>"$out/zap.log" 2>&1 || true; }
  : >"$out/zap.log"
  if [ "${DAST_FULL:-0}" = 1 ]; then
    zap zap-full-scan.py -t http://pogi-scan:7644/_pogi/ -J zap-full.json -r zap-full.html
    files="zap-full.json"
  else
    zap zap-baseline.py -t http://pogi-scan:7644/ -J zap-root.json -r zap-root.html
    zap zap-baseline.py -t http://pogi-scan:7644/_pogi/ -J zap-console.json -r zap-console.html
    files="zap-root.json zap-console.json"
  fi
  n=0
  for f in $files; do n=$((n + $(count '"alert"' "$out/$f"))); done
  row dast "$zap_image" "$n alerts" "$(echo $files | tr ' ' ',')"
}

# --- run ---------------------------------------------------------------------

for t in $tools; do
  "scan_$t"
done

echo
cat "$out/SUMMARY.md"
[ $fail = 0 ] || { echo "FAILED: see the FAIL rows above" >&2; exit 1; }

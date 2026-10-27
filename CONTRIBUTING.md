# Contributing to pogi

## Build and test

You need Go (the version in `go.mod`). Nothing else is needed for the unit tests.

```
go build -o pogi ./cmd/pogi     # build the binary
make test                       # go vet, then go test with the race detector
make generate                   # rewrite docs/reference/coverage.md and the README Services table
```

- Format code with `gofmt`. CI fails if `gofmt -l .` lists a file.
- CI (the `preflight` workflow) runs `gofmt`, `go vet`, golangci-lint, the race tests, a cross-compile for six platforms and the
  conformance blocks. See "Run CI locally" below.
- If you change a service, run `make generate`. A test fails when the generated
  coverage files are out of date, or when a registered service has no row in
  `docs/reference/coverage.yaml`.
- `scripts/conformance.sh` runs real Terraform and CDK projects against a fresh pogi.
  It needs `terraform`, Node.js with npm, and `python3`, and it downloads providers and packages.
  It uses port 4599 unless you set `POGI_PORT`. Run one copy at a time.

## Run CI locally

Every CI job calls `scripts/ci.sh`, so you can run the same checks on your machine:

```
scripts/ci.sh                   # fmt, vet, build, cross, release-check, lint, workflows, and all test groups
scripts/ci.sh lint              # one step (make lint)
scripts/ci.sh groups            # the test group names, one per line
scripts/ci.sh test aws          # the race tests of one group: core, aws, azure or gcp (make test G=aws)
scripts/ci.sh conformance aws   # one conformance block
scripts/ci.sh gate              # race tests with Docker on, all conformance blocks, then the browser tests (make gate)
```

- Steps: `fmt`, `vet`, `build`, `compile`, `cross`, `release-check`, `lint`, `workflows`, `coverage`, `groups`,
  `test <group|all>`, `conformance [block ...]`, `security [tool ...]`, `e2e` and `gate`.
- Tools you do not have are skipped with an install hint: golangci-lint, GoReleaser and zizmor
  (`brew install golangci-lint goreleaser zizmor`). In CI a missing tool fails the step.
- The test groups are core, aws, azure and gcp (the packages of each cloud, and the rest). A new package
  must be in exactly one group: `scripts/ci.sh coverage` fails until you add it to `group_pattern` in
  `scripts/ci.sh`.
- CI runs the race tests with Docker off, so tests that need containers skip themselves. `gate` runs them.

## End-to-end tests

`test/e2e` has browser tests (Playwright, Chromium only) that drive the console against a real pogi. They cover
live refresh of the S3 page, the paused-refresh hint, region and account scope, the objects drawer, the console
forms and a page of 200 buckets.

```
scripts/ci.sh e2e                          # install, then run every test
cd test/e2e && npx playwright test live    # one file (after one run of the line above)
```

- Needs Node.js, Go and, for the first run, a download of Chromium. One test uses the `aws` CLI and skips itself
  without it.
- The config builds pogi from the repo, starts it on port 17645 with a temporary data folder and stops it at the
  end. Set `POGI_E2E_PORT` to use another port. A port that is taken fails the run. It never uses 7644.
- Every test starts with empty S3 and SQS. Wait for something to appear with `expect(...)`, not with a sleep.

## Security scans

`scripts/security-scan.sh` reruns the security checks on pogi:

| tool | what it checks |
|---|---|
| `vuln` | known CVEs in Go modules the code calls (govulncheck) |
| `gosec` | Go code scan |
| `semgrep` | Go, JS, Dockerfile and workflow code scan |
| `trivy` | dependencies, secrets and misconfig in the tree |
| `secrets` | secrets in the git history (Gitleaks) |
| `image` | the Docker image (builds `pogi:scan`, then Trivy) |
| `dast` | the running server, scanned from outside with OWASP ZAP (set `DAST_FULL=1` for the slower active scan) |

```
scripts/security-scan.sh              # every tool
scripts/security-scan.sh vuln gosec   # only the tools you name
```

- Each tool uses the program on your PATH, or a pinned Docker image if it is not installed. A tool with neither is skipped.
- Results go to `scan-results/` (not committed): one raw file per tool and `SUMMARY.md` with one row per tool.
- The run fails only for a fixable HIGH or CRITICAL CVE found by Trivy, a vulnerability that govulncheck says the code calls, or a secret found by Trivy.
  gosec, Semgrep, Gitleaks and ZAP only report. Test fixtures and the emulator's sample keys are expected hits.

## Send a change

1. Fork the repo and make a branch.
2. Make the change, with a test. Tests use the official SDK of the cloud they cover.
3. Run `make test`.
4. Open a pull request. Say what changed and why, in plain words.

The docs are in `docs/` and follow the Diátaxis shape (tutorials, how-to guides, reference, explanation).
`docs/reference/coverage.md` and `docs/reference/aws-long-tail.md` are generated; do not edit them by hand.

# Adding a service

Every emulated service is one package under `internal/<cloud>/<service>/`, registered in
`pogi.go`. Read `internal/aws/sqs/sqs.go` (RPC/JSON + Query) and `internal/aws/s3` (REST) first.
They are the reference implementations.

## Long-tail services: a model instead of a package

An AWS service that needs only create, describe, list, update, delete and tags (IaC-grade) does not get
a package. Add its botocore directory name to `internal/aws/generic/services.txt`, run
`go generate ./internal/aws/generic`, and write an SDK test. Quirks go in small overrides. See the
package doc of `internal/aws/generic`.

## The contract (`internal/core`)

```go
type Service interface {
    Info() core.Info                   // Name, Cloud, Title, Targets, Signing, Match, Protocol
    ServeHTTP(http.ResponseWriter, *http.Request)
}
// optional
Save() ([]byte, error); Load([]byte) error; Reset()  // core.Stateful: persistence, snapshots, reset
Resources() []core.Table                              // core.Browsable: console, TUI, `pogi ls`
Inspect(table, id string) any                         // core.Inspectable: JSON detail of one row
```

- `Info.Name` is the LocalStack-style service name (`dynamodb`, `sns`, `events`, `stepfunctions`).
- How the gateway finds the service:
  - **JSON-protocol services** list their `X-Amz-Target` prefixes in `Targets` (`DynamoDB_20120810`).
  - **Query and REST services** list SigV4 signing names in `Signing` (`sns`, `lambda`). Query services also
    list their smithy service name in `Targets` (`AmazonSimpleNotificationService`), so pogi's in-process
    `hub.Call` can reach their typed ops over JSON.
  - **Path- or host-routed traffic** (GCP, API Gateway invoke URLs) uses `Match`.
- The console builds its create forms for you (`internal/web/forms*.go`):
  - generic-engine services get them from the botocore model;
  - Google services get one per `Create*` RPC that has a REST binding, from the protobuf request;
  - Azure services need nothing (the console's JSON editor covers every type registered with `arm.Register`);
  - a hand-written AWS service adds its common creates to `curated` in `forms_aws.go`, and its
    delete/tag calls to `bulkSpecs` in `bulk.go`, if its tables should offer bulk actions.
- `core.C(r)` returns the request `*core.Ctx`: Account, Region, Host, RequestID and Op.
  `core.Body(r)` returns the buffered body.
- Once the operation is known, call `c.Intercept()` and return its error in your protocol. It checks
  the SigV4 signature (when enabled), then applies chaos rules and IAM enforcement.
- A service that mints AWS credentials registers them with
  `hub.AddIdentity(akid, core.Identity{…, Secret: secret})`, so that signature checking accepts them.
- Errors are `core.Errorf(status, "Code", "message")`. Use the real AWS error codes: SDKs branch on them.

## RPC services (AWS JSON 1.0/1.1 and Query)

Write each operation once, as a typed function. `core.RPC` decodes JSON or Query input into
`*In` and encodes the output in the caller's protocol:

```go
s.rpc = &core.RPC{JSONVersion: "1.1", XMLNS: "…", Ops: map[string]core.Handler{
    "CreateThing": core.H(s.createThing),
}}
func (s *Service) createThing(c *core.Ctx, in *createThingInput) (any, error) { … }
```

- Input and output field names are the AWS member names. Go's JSON matching is case-insensitive.
- Use `json:",omitempty"` so that empty optional outputs stay absent.
- Timestamps in outputs use `core.Time`. It encodes as epoch seconds in JSON, as a tag-1 epoch in
  CBOR and as ISO 8601 in Query XML. `core.Unix(t)` returns the raw number.
- Services whose SDKs speak **RPCv2 CBOR** (for example CloudWatch from Go and Java) list the smithy
  service name in `Targets`. `core.RPC` then decodes and encodes CBOR automatically.
- Query field names come from the `json` tag or the field name. Add
  `query:"Name,flat,key=K,val=V"` for flattened lists or maps and for custom entry names.
- Return `nil, nil` for operations with an empty output.

## Cross-service wiring

- Fan-out goes through the hub. Senders never import the target package:
  - **Send:** `hub.Deliver(targetARN, &core.Message{Body: …})`.
  - **Receive:** register once in `New` with `hub.OnDeliver("myservice", func(arn string, m *core.Message) error {…})`.
- Synchronous Lambda calls use `hub.Invoke(arn, payload)`.
- To call a JSON-protocol (or Query) service in-process, as pollers and CloudFormation do, use
  `hub.Call(account, region, "TargetPrefix", "Op", in, &out)`. For REST services use
  `hub.Do(account, region, signing, method, path, header, body)`.
- LocalStack-style internal endpoints (outboxes, peeks) are mounted with `hub.Mount("/_aws/…", handler)`.

## State and concurrency

- Keep all state in one exported `state` struct with JSON tags, guarded by one mutex. `Save` and
  `Load` marshal that struct.
- Unexported fields (channels, timers) are skipped by JSON. Recreate them lazily after `Load`.
- Never hold your lock while calling `hub.Deliver`/`hub.Invoke`. Collect the deliveries, unlock, then send.
- Background work (TTL expiry, schedules) runs as `s.stop = core.Every(time.Second, s.Tick)` in `New`. It must be
  cheap when idle. Stop it in `Close() error`, which the hub calls on shutdown. Export `Tick(now)` so tests can
  drive time.

## Tests

Each service has `<service>_test.go` in an external test package (`package foo_test`). It uses the
**official SDK** against an in-process server:

```go
_, url := core.ServeTest(t, func(h *core.Hub) core.Service { return mysvc.New(h) })
client := dynamodb.NewFromConfig(awstest.Config(t, url))
```

- Cover the main flows and the error codes SDKs depend on.
- Run `go test -race ./internal/aws/<service>/`.
- Run `gofmt -w` on your files.
- Tests are the wire-compatibility contract. If the SDK accepts it, AWS-shaped clients will too.

## Checklist
- [ ] Package with `Info`, `ServeHTTP`, `Save/Load/Reset`, `Resources`, `Inspect`
- [ ] Real error codes and HTTP statuses
- [ ] Deliveries outside the lock; `OnDeliver` if the service can be a target
- [ ] SDK tests, `-race` clean
- [ ] Registered in `pogi.go` (maintainer); a row in `docs/reference/coverage.yaml` naming the service (depth, covered, not yet), then `go generate .` rewrites `docs/reference/coverage.md` and the README's Services table. `go test ./test` fails until every registered service is in a row

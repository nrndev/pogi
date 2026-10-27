# Changelog

All notable changes to pogi are written down here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and pogi uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security

- **The container image is scanned for known CVEs.** Every preflight builds the image and fails on a fixable HIGH or CRITICAL CVE, and a weekly job scans the published image and reports to GitHub's Security tab.

## [0.2.0] - 2026-10-27

### Security

- **The MCP endpoint refuses other websites.** `/_pogi/mcp` now has the same cross-origin check as the admin API, so a page on another local port can no longer call its tools.
- **More secrets are hidden in Activity.** SSM SecureStrings, Key Vault values, Google Secret Manager payloads, Azure SQL passwords, Lambda environment variables, Cognito tokens, security-token and API-key headers and query values now show as `[redacted]`. Names stay visible.
- **`evil.xlocalhost` is no longer treated as localhost.** Only `localhost`, `*.localhost` and the `-localhost` form pogi uses count.
- **The console's Azure role script quotes every value.** The least-privilege script put recorded scopes, the object id and the role definition into `az` commands without shell quoting, so a `'`, `;` or `$(...)` in a recorded value could run as a command when the script was run.
- **Each release has SLSA provenance.** `pogi.intoto.jsonl` on the release page is a signed record of how and from what source the archives and packages were built; `slsa-verifier` checks it ([how to check a download](docs/how-to/install.md)). GitHub's build attestations are still there too.
- **The Docker image's base images are pinned by digest,** so a changed upstream image cannot slip into a build. CodeQL now scans the Go code on every push and pull request.
- **Built with Go 1.27.3.** Go 1.27.2, which built 0.1.0, still trusted certificates from eight eMudhra intermediate certificate authorities whose keys were stolen ([GO-2026-6809](https://pkg.go.dev/vuln/GO-2026-6809)). Go 1.27.3 rejects them, so pogi's outbound HTTPS connections do too.

### Fixed

- **Python's BigQuery client reads TIMESTAMP columns.** `list_rows`, `query().result()` and `to_dataframe()` without the Storage Read API failed with "is not an int": the client sends `formatOptions.useInt64Timestamp=True`, and pogi only read lowercase `true`. Google services now read true/false query values in any case, as Google does (also Cloud Storage `versions`, `includeTrailingDelimiter` and BigQuery `deleteContents`).
- **Azure `$filter` works on resource and group lists.** `az resource list -g <group>` (with `--resource-type`, `--tag`) and `az group list --tag` now return what they ask for; the resource list used to be empty. A filter pogi cannot read is refused with a 400 `InvalidFilter`, as Azure does, instead of being ignored.
- **Lambda runs your code with a relative `--data-dir`.** With a path such as `--data-dir ./data`, a function run on your machine (not in Docker) failed with "Runtime exited during init". The runtime starts inside a folder under the data dir, so the relative path to its bootstrap pointed nowhere. pogi now turns the data dir into a full path at start.
- **Google create forms work.** The field the URL needs (such as `parent`) is now first in the form, and a `locations/*` part is filled in (`projects/pogi/locations/us-central1`). GKE "Create cluster" no longer fails for a missing parent.
- **Empty pages only offer Create when there is a button.** Otherwise they say to use the CLI, SDK or Terraform.
- **Saving an Azure resource names it** ("Managed cluster aks1 saved") and opens the service page that lists it.
- **Generated form titles use sentence case** ("Create node pool"), like the hand-made ones.
- **S3 buckets show in every region.** A bucket made in another region no longer vanishes from the S3 page when the region switcher is on `us-east-1`. Real AWS lists every bucket in the account, and so does pogi now.
- **A paused live refresh says so.** While you type, or have a drawer, dialog or ticked row open, a service page waits to refresh and now shows "Updates paused while you work here".
- **gcloud's GKE and Artifact Registry commands reach pogi.** `pogi env` sets their endpoint overrides; before, `gcloud container …` went to Google and failed with 401.
- **GKE: `gcloud container clusters create` and `delete` wait for their operation**, with no `--async`, and `clusters list` works without `--location`.
- **Cloud Functions: `gcloud functions deploy` needs no `--build-service-account`**, and `--allow-unauthenticated` works.
- **CloudFormation: a stack with no parameters can be updated with `aws cloudformation deploy`.** `GetTemplateSummary` sends an empty `Parameters` list, as AWS does.
- **Event Grid honours `queueName`** on Storage queue destinations, names a topic in its real resource group, and pogi's certificate covers the topic's own HTTPS endpoint.
- **Cloud Tasks lists locations.**
- **A pogi never removes another running pogi's containers**, such as the shared ECR forwarder.
- **`pogi ls` and the console show a long-tail resource's name.**
- **The Run buttons of the SQL editor and Logs** keep the shortcut (⌘↵ or Ctrl↵) in their tooltip instead of a key chip.
- **Numbers too big for their field are refused, not wrapped.** A Service Bus `MaxDeliveryCount` of 4294967297 was stored as 1, and a non-number became the default. Google `maxResults` and page sizes above 2147483647, Firebase Auth's `maxResults`, Cloud Logging severities and the console's Firestore limit wrapped the same way. They now get the cloud's 400, or are ignored where a number is optional.
- **Extra arguments are an error, and flags work anywhere.** Commands used to ignore words they do not take, so `pogi start version` started the server, and a flag after an argument was dropped, so `pogi ls s3 --endpoint URL` quietly used the default endpoint. Now pogi names the argument it did not expect. Flags may come before or after the arguments (`pogi snapshot --endpoint URL ls` works too), and `-h` at the end of any command prints its help.
- **`pogi reset` refuses empty and unknown names.** `pogi reset ""`, as from an unset variable in a script, used to reset every service, and a misspelled name reported success while resetting nothing. Both now fail with a message. `pogi reset` with no name still resets everything.
- **Bad settings from flags and environment variables fail.** `--iam stict`, `--storage bogus` or `POGI_PORT=abc` used to start pogi anyway. They now get the same checks as `pogi.yaml`. An unknown name in `--services` fails too and suggests close names; if you set LocalStack's `SERVICES`, every name in it must be one pogi has.
- **Chaos rules are checked.** A status outside 400-599, a rate outside 0-1 or a negative latency is refused by `pogi chaos add`, the console, MCP and the admin API, and `pogi.yaml` checks latency too. `pogi chaos ls --status 500` and the like fail, since those flags only mean something to `add`.
- **Client commands give up on a pogi that does not answer.** They used to wait forever; now they stop after 2 minutes and say so.
- **A failed `pogi snapshot export` leaves no file.** The file used to be created before the download, so an unknown name left an empty file. Now it appears only once the whole snapshot has arrived.
- **The start banner's `pogi env` hint fits the port.** On a port other than the one `pogi env` uses by default, it now shows `pogi env --endpoint URL`.
- **Bad client flag values fail.** `pogi env --shell nushell` used to print `sh` syntax, and `pogi logs -n -5` was accepted. Both now stop with a message.
- **Removing things says so.** `pogi snapshot rm`, `pogi chaos rm` and `pogi chaos clear` print what they removed.
- **`NO_COLOR` and `TERM=dumb` are respected.** `pogi cost` prints no bold text and `pogi pull` no redrawn progress line when either is set.
- **`pogi clean -h` prints its `--data-dir` flag correctly.**
- **Every command's help says what it does.** `-h` and `pogi help <command>` now show a one-line summary, the usage, an example and the flags, spelled `--name` as in these docs. Help goes to standard output, so it can be piped to `grep` or `less`.
- **Ctrl-C on `pogi start` answers at once, and a second one quits.** pogi used to print nothing until every container had stopped, and ignored a second Ctrl-C. Now it prints `Stopping… (press Ctrl-C again to quit now)` right away, and a second Ctrl-C ends it without waiting. `pogi clean` removes any container left behind.
- **`pogi clean` no longer asks when no one can answer.** Without a terminal it used to print `Delete these? [y/N]`, read no answer, delete nothing and exit 0, so a forgotten `--yes` in CI went unnoticed. Now it stops and asks for `--yes` or `--dry-run`. When some deletes fail, it prints each reason, counts only what it deleted and exits 1.
- **`/dev/null` is not a terminal.** pogi took any character device for a terminal, so `pogi clean < /dev/null` would prompt and `pogi start < /dev/null` could try to open the terminal screen. pogi now asks the system whether it is a real terminal.
- **Plainer errors for a missing snapshot, a missing path and a pogi that is not running.** `pogi snapshot rm`, `load` and `export` with an unknown name used to show the server's file path or `404 page not found`; now they say `no snapshot named "x" (pogi snapshot ls lists them)`, and the admin API answers 404. `pogi cost`, `pogi pull` and the MCP tools say `/x was not found`, not `stat /x: no such file or directory`. A pogi that is not running is `cannot reach pogi at …`, not `pogi: pogi is not reachable at …`.
- **An unknown service name is an error, not an empty list.** `pogi ls nosuch` and `pogi logs --service nosuch` used to print nothing and exit 0, which looked the same as "no resources". Now they fail with `no enabled service "nosuch" (pogi services lists them)`. The admin API answers `GET /_pogi/api/resources?service=` and `GET /_pogi/api/requests?service=` with 404 for a service that is not running. The terminal screen's Logs tab asks only for the log services that run, so it works with CloudWatch Logs or Cloud Logging turned off.
- **`pogi tf diagram` opens no browser in CI.** When standard output is not a terminal, it prints the page's address, as `--no-open` does.
- **`pogi status` shows problems.** Saved state pogi can't read or write, and ports it could not open, used to show only in the console and the terminal screen. `pogi status` now lists each under its first line, in red in a terminal.
- **A busy port is said once, and everywhere.** With `--headless`, a busy SMTP, AMQP or Azure Storage port showed as a `level=WARN` log line and again in the banner. Now the banner says it once (`--debug` logs it too). It is also a pogi problem: the terminal screen counts it in its header and lists it on the Overview tab, the console shows a banner and the bell a note, and `/_pogi/api/info` lists it under `problems` with `"kind":"port"`. Before, a busy port showed nowhere in the terminal screen.
- **Usage errors exit with 2.** A bad flag, a bad flag value, an argument a command does not take or a missing one now exits with `2`, in every command. Other errors still exit with `1`. A bad flag's message names the command and points to its `-h`.
- **`pogi --version` and `pogi -v` print the version.** They used to be read as unknown server flags and failed.
- **The terminal screen showed calls more than once.** Each tab switch started one more background refresh, so the same call could appear several times and the counts went up. Now there is one refresh. Log lines with line breaks or terminal escape codes no longer break the screen.
- **Snapshots are checked before they load.** A snapshot from a newer pogi, an empty one (`{}`) or one that does not decode is refused with a plain message that names the service. A load is all or nothing: if one service fails, the state stays as it was. A service this pogi does not know is skipped with a warning.
- **Saved state survives a power cut.** The state writer now flushes the temp file to disk before the rename, and the folder after it.
- **EC2 `RunInstances` honors `ClientToken`.** The same token with the same parameters returns the first call's reservation (also when many calls arrive at once); the same token with other parameters returns `IdempotentParameterMismatch`. Tokens are saved with the instances.
- **A code zip with a `../` or absolute entry is refused at upload.** Lambda `CreateFunction` and `UpdateFunctionCode` answer `InvalidParameterValueException` naming the entry; Azure Functions and Google Cloud Functions use the same check when they unpack.
- **A model call stops when the client leaves.** Bedrock, SageMaker, Comprehend and Translate calls to your local model now end with the request, not after a fixed 5 minutes. The limit is `ai.timeout` in `pogi.yaml` (default `5m`).
- **Busy ports are said plainly.** A busy main port exits 1 with "port N is in use (another pogi?); use --port". A busy SMTP, AMQP or Azure Storage port now shows in the start banner, next to its name.
- **A registry that never answers is named as one.** A timed-out image download says "The registry can't be reached". Calls pogi makes to your function host, a blob copy source and the Spanner emulator now have a time limit.
- **A restarted container no longer waits on port 0.** Docker names a container's host ports a moment after a start
  or restart; pogi read them at once, so under load an MQ broker reboot could wait 5 minutes on a port it never had.
  pogi now waits until Docker has named every published port, and says so if it never does.
- **A Lambda function that does not start in time says why.** The error names the slow part: the runtime never asked
  for work, or an extension had not finished its init, with the time each part became ready. The limit is
  `lambda.initTimeout` in `pogi.yaml`: AWS's 10 seconds by default; raise it on a slow or busy machine.
- **Databases keep their data in a volume.** Each database container mounts a Docker volume named
  `<container>-data`. A container that was removed, or won't start, is made again on the same volume, so its data
  stays; "recreated empty" is said only when the volume is gone too. A new database and a snapshot restore start from
  an empty volume. Deleting a resource, `pogi reset` and exiting without saved state remove the volumes. `pogi clean`
  now lists the containers and volumes kept for a data folder's saved state by folder, with `pogi clean --data-dir
  <folder>` to delete them.
- **Malformed requests get plain errors.** A request body that isn't JSON, or has a field of the wrong type, is answered
  with a sentence such as "the request body is not valid JSON" or "field QueueUrl must be a string, not number", in each
  cloud's own error shape. Go's parser text, when shown, follows after " — ". A bad `plan.json` is refused the same way.
- **Odd names are checked.** Azure resource group names (1 to 90 characters) and Blob container names (3 to 63 lowercase
  letters, digits and single hyphens) are refused with Azure's error codes, and GCS bucket names over 63 characters
  (222 with dots) with GCS's `invalid` error. A Pub/Sub name with `%2F` is refused as an invalid name instead of
  answering 501.
- **Saved state is safer.** One data folder is used by one pogi: a second one exits with "another pogi (pid N) is using
  <folder>". A state file that won't load is kept as `<name>.corrupt-<time>` and never overwritten, and the console
  bell and `/_pogi/api/info` say so. pogi stops at start, with a plain message, when it can't use the data folder or
  read an old `state.json`, instead of running without saving. A failing save (disk full, no permission) is logged
  once, shown in the console banner, the bell and status, and clears itself when saving works again.
- **Huge or deeply nested input no longer hurts pogi.** A Terraform file that nests deeper than 200 levels is refused with
  "<file>:<line>: nested too deep (over 200 levels)" (it used to crash all of pogi), and a crash while reading one is a plain
  400. Every console form now stops at the upload limit instead of filling the disk, and a refused upload shows its real
  size. SQS, DynamoDB and the other JSON and query APIs answer `413` for a body that is too large, not "does not
  implement".
- **Containers and Docker.** Every Docker call (create, start, inspect, remove, exec) now ends after 2 minutes, so an
  engine that never answers no longer leaves a database "creating" for ever or holds up shutdown. A dead or
  silent engine gives "Docker isn't running" or "Docker stopped answering", not raw network text, and a
  download cut by a dying engine no longer blames the registry. pogi now watches the container of every database,
  cache and k3s cluster (RDS, ElastiCache, MemoryDB, Cloud SQL, GKE, EKS, AKS and the others that run one): one
  that stops on its own turns "failed", with a note such as "killed: out of memory (raise Docker's memory limit)"
  or "stopped: exit 1 — <last log line>", and a container that dies while starting fails at once, not after 5
  minutes. A container removed while pogi was stopped is recreated with the note "its container was removed
  while pogi was stopped, so it was recreated empty". The console's Status column for databases, caches and
  similar resources now shows the note next to the status, such as "available · no database: Docker isn't running".

### Added

- **ARM templates and Bicep files deploy for real.** `az deployment group create` and `az deployment sub create` now make the template's resources, through pogi's own services and in `dependsOn` order. Templates can use parameters, variables, `copy` loops, conditions, nested deployments (Bicep modules), outputs and the common template functions such as `resourceId`, `reference`, `listKeys` and `uniqueString`. Bicep works too, because `az` turns it into a template first. A deployment ends Succeeded, or Failed with the error of the resource that failed. `az deployment operation group list` shows each step, and `az deployment group validate` checks a template without making anything. Before, a deployment was only stored, and `az deployment group create` failed on its first call.
- **Azure Resource Graph answers queries.** `az graph query` runs KQL (the Kusto query language) over pogi's resources (the `Resources` table) and its subscriptions and resource groups (`ResourceContainers`), with Azure Monitor's KQL subset. Results come in pages with `$skipToken`, as objects or as a table, and a bad query gets a 400 that says what is wrong. Before, every query answered an empty object.
- **Azure Policy is evaluated.** A create or update through Resource Manager that a `deny` policy of its subscription or resource group matches is refused with `RequestDisallowedByPolicy` and the policy's name. `az policy state list` and `az policy state summarize` report each resource against each `deny` and `audit` policy in scope, so a test can check that a resource is non-compliant. Rules use `if`/`then`, `field`, `value`, `allOf`, `anyOf`, `not`, all the operators and parameters. A rule with an unknown operator, and an assignment with a missing or unknown parameter, are refused. Before, policies were stored and never applied.
- **Azure pages list what Create makes.** Key Vault has a Vaults tab, Cosmos DB an Accounts tab, and App Service an App Service plans tab, so a saved resource shows up on its page.
- **Azure create everywhere.** Azure service pages have a Create button that opens the resource editor with the page's type picked. The editor has a Name field and builds the ID from the scope, and its starting bodies work as they are for the common types. A save returns to the page you came from. Resource Manager has a "Create resource group" form, and a group's drawer lists its resources.
- **Account center.** The scope pill now has Google location and Azure resource group and location, each a pick-or-type list filled from what pogi holds. Tables, counts and creates follow them, the bar above a table says how many rows are hidden, and "Reset to defaults" clears them. A create form drawer shows the scope of its own cloud.
- **Quieter, clearer notifications.** A 404 from a read no longer counts as an error in the bell, the sidebar or Home. The bell's toggles are real buttons, titles use service names, and it links to all errors in Activity. Toasts queue, pause under the pointer, and several new errors become one summary.
- **Data actions in the console.** DynamoDB's Query tab adds, edits and deletes items. Pub/Sub has a Messages tab to pull and ack messages. Kinesis has a Records tab to put and read records.
- **Lambda actions in the console.** Delete a function (row menu or bulk), update its code from a `.zip`, edit its environment variables, and create an event source mapping. The Invoke box now really starts with `{"hello": "pogi"}`.
- **Step Functions: start and stop executions** from the Run tab.
- **SNS: create and delete subscriptions** in the console.
- **EventBridge: rules get targets.** "Put rule" has a Targets list, and deleting a rule removes its targets.
- **Kubernetes in the console.** EKS, GKE and AKS get a short "Create cluster" form (AKS gets a Create button at all). A ready cluster's drawer has "Connect with kubectl": a kubeconfig download, the command to fetch it the cloud's way, and a `kubectl get nodes` line.
- **Browser tests for the console.** `test/e2e` drives the S3 page in Chromium (Playwright) against a real pogi. Run it with `scripts/ci.sh e2e`; `gate` runs it too.
- **How-to guides for each kind of service.** Thirteen guides in `docs/how-to/` get a service working in a few minutes, with the commands for AWS, Google Cloud and Azure and the output they print: storage, queues and topics, key-value and document databases, secrets and keys, functions and HTTP APIs, events and workflows, Kubernetes clusters, containers and VMs, SQL databases and caches, sign-in, logs and metrics, CloudFormation, and any Thin service. Rows on the [coverage page](docs/reference/coverage.md) link to them.
- **The Azure CLI signs in to pogi.** `pogi env` sets `AZURE_CORE_INSTANCE_DISCOVERY=false`. After `az cloud register` and a service-principal `az login` ([how](docs/how-to/connect-your-tools.md#azure-cli)), ARM commands such as `az group`, `az aks`, `az keyvault`, `az network dns`, `az eventgrid` and `az postgres` or `az mysql flexible-server create` reach pogi.
- **`gcloud run deploy` works.** pogi serves Cloud Run's Knative v1 API on the regional host gcloud calls, and `pogi env` points gcloud's Cloud Run API at `run.localhost` so that host resolves.
- **The console fits every width from 768px to 1920px.** No page scrolls sideways, toolbar fields stretch and shrink with Run at the end of its row, tables hide the columns you can spare on narrow screens (the drawer still shows them), and the footer sits at the bottom edge. A polish pass lined up headers, cards, drawers and numbers across pages.
- **JSON from the list commands.** `pogi status`, `services`, `ls`, `snapshot ls` and `chaos ls` take `--json`, `pogi logs --json` prints one JSON object per call, and `pogi cost --json` is short for `--format json`.
- **Help for each command.** `pogi help <command>` shows that command's flags, the main help names `pogi tf diagram` and links the docs and the issue tracker, and `pogi version -h` works.
- **Long and short flag names.** `logs --follow` and `--lines` (for `-f` and `-n`), `start -q` (for `--quiet`) and `tf diagram --output` (for `-o`).
- **`-` in snapshots.** `pogi snapshot export NAME -` writes to standard output, and `pogi snapshot import - NAME` reads standard input.
- **A clearer terminal screen.** Every list in the TUI is now a table with column headers, and narrow windows drop the least important columns first.
  - The top line shows whether pogi is ready, whether state is saved, the IAM mode, the region, the chaos rules and any saved-state problems.
  - Overview (was Dashboard) adds errors, average time and the last call for each service in use, calls per second, and the top errors.
  - Requests shows the selected call's details under the list, filters by cloud, and sorts by time, slowest or errors first.
  - Resources lists the services that hold something, beside their tables. Logs has a level column, a filter and a warnings-and-errors switch.
  - A new Flows tab lists the steps where one service hands work to another, such as an SNS message delivered to SQS.
  - Loading or deleting a snapshot and resetting one service now ask first. Inside `pogi start`, the footer says that `q` stops pogi.
- **`GET /_pogi/api/spans`** returns the recent flow steps: deliveries, function runs, dead-letter moves and notifications.
- **Image downloads you can see.** The console shows an image download and a container start in the resource's row, tells the bell
  when a resource is ready or a download failed (mute it with "Your resources"), and serves the work as JSON at
  `/_pogi/tasks`. A download fails when no data arrives for 2 minutes, or after 30 minutes, and Docker's errors come
  as plain sentences. `pogi pull <folder | plan.json>` (also `--all` and `--list`) downloads the images a stack needs ahead of time.
- **Clearer feedback in the console.** Buttons show they are busy and cannot be double-clicked. Messages name
  the resource ("Bucket photos created"), and pages you reach by redirect show a success bar. Deleting asks in
  pogi's own dialog, and removing a single chaos rule now asks too. Resource tables refresh themselves while a
  row is creating or deleting, a row shows image download progress or the plain reason it failed, and a top-bar
  indicator lists background work. Writes made in the console now appear in Activity with a "console" label.
- **Service icons in the console.** Every service now has its cloud's own icon (AWS, Azure and Google Cloud; a
  service with none shows a plain glyph). They show in the sidebar, the collapsed sidebar, each service page's
  header, `⌘K` results and Map nodes. The Terraform diagram uses the same icons. The counts now say how many
  services pogi covers (counted as products, with the Deep, Core and Thin split), Flows has its own sidebar
  link, service names on the Services page wrap instead of being cut off, Deep, Core and Thin badges explain
  themselves, and a service filled from the console shows under "In use".
- **Terraform cost.** `pogi cost ./infra` works out what a Terraform folder or a `plan.json` would cost a month
  on the real cloud. pogi reads the files itself and never runs Terraform. Each row says how sure pogi is
  (known, assumed, usage or needs), and a plan shows the cost before, after and the change. It prices AWS and
  Azure from price lists built into pogi, with no network. Google Cloud prices are not included yet. There is
  also a usage file, a size what-if (`--size`, `pogi cost sizes`), and output as a table, JSON or Markdown.
  The console's Cost page has a Terraform tab with a size picker, and the `estimate_terraform_cost` and
  `list_sizes` MCP tools give agents the same numbers. See
  [Estimate Terraform cost](docs/how-to/estimate-terraform-cost.md).
- **A diagram of your Terraform.** The new Terraform page draws each resource as a box, the references between
  them, and what a plan creates, updates, replaces or deletes, with what depends on each change. You can group
  by module or by network (VPC, VNet or Google network, with their subnets as frames), pan, zoom and export it
  as SVG or PNG. pogi keeps the last stack in memory, so the Cost page's Terraform tab shows the same one. See
  [See what a plan changes](docs/how-to/see-what-a-plan-changes.md).
- **`pogi tf diagram [path]`** sends a Terraform folder or plan to the running pogi and opens the Terraform page.
  With `-o diagram.svg` it writes the SVG with no running pogi.
- **11 more AWS services.** X-Ray keeps the traces you send
  and finds them again, with sampling rules and targets. A DAX cluster's endpoint is pogi's own DynamoDB, so a
  plain DynamoDB client pointed at it works. Amplify, Polly, Shield, CodeCommit, Location, Keyspaces,
  FSx, Resource Groups and CodeStar Connections keep their resources, so Terraform and the SDKs can create,
  read, update and delete them, but nothing runs behind them. See [Coverage](docs/reference/coverage.md).
- **38 more AWS services on the generated engine:** AppFlow, MediaConvert, IVS, Security Lake, QuickSight,
  Managed Grafana, VPC Lattice, Direct Connect, WorkSpaces, WorkSpaces Secure Browser, AppStream 2.0, Directory
  Service, Signer, Elastic Disaster Recovery, Cloud WAN, Device Farm, License Manager, MediaLive, MediaPackage,
  GameLift, Kinesis Video Streams, DataZone, Data Exchange, Clean Rooms, Resilience Hub, Application Recovery
  Controller, Payment Cryptography, Private CA, Firewall Manager, User Notifications, Compute Optimizer, Cost
  Optimization Hub, EC2 Image Builder, Storage Gateway, End User Messaging, Serverless Application Repository
  (its applications deploy through pogi's CloudFormation), Oracle Database@AWS and Aurora DSQL. Terraform and the
  SDKs can create, read, update and delete their resources, but nothing runs behind them.
- **Google Cloud services that really run.** Spanner runs Google's own emulator in Docker behind pogi's port.
  Bigtable runs Google's own emulator inside pogi, with no Docker, and pogi adds the instance admin API that
  emulator lacks. Each Memorystore for Redis instance is a real Redis container, and its `host` and `port` work
  for a client. Workflows runs your workflow's YAML: `assign`, `call` (HTTP, `sys.*` and subworkflows), `switch`,
  `for`, `try` with `retry`, `return` and `raise`. A step pogi doesn't support fails the execution with an error
  that names it.
- **Azure services that really run.** App Service web apps run their container image, or zip-deployed Node or
  Python code, at `<app>.azurewebsites.localhost`. Azure Files serves shares, directories, files and ranges.
  Data Lake Storage Gen2 serves the `dfs` endpoint on Blob Storage, with real directories and renames. A Cosmos DB
  account of kind MongoDB runs on a real MongoDB, and `listConnectionStrings` returns a string that a Mongo
  driver connects with.
- **More Thin services for Google Cloud and Azure.** Two new engines, like the one behind AWS's long tail, build
  services from Google's API descriptions and Microsoft's API specs. On them run Google Cloud services such
  as Cloud DNS, Filestore, Cloud Build, Dataproc and AlloyDB, and Azure services such as DNS, Policy, Front Door,
  Application Gateway, Firewall, Data Factory and Databricks.
  Terraform and the SDKs can create, read, update and delete their resources, but nothing runs behind them.
  Azure still refuses a resource type that pogi doesn't list, with a clear error.
- **<!-- count:total -->355 services: 144 AWS (90 with real behavior, 54 Thin), 108 Google Cloud (25 with real behavior, 83 Thin) and 103 Azure (30 with real behavior, 73 Thin)<!-- /count -->,** each product counted once. See [Coverage](docs/reference/coverage.md).
- `pogi env` now points gcloud at every Google API that pogi serves, and sets `SPANNER_EMULATOR_HOST` and
  `BIGTABLE_EMULATOR_HOST`. Some Google APIs share their paths, so pogi tells them apart by a prefix, such as
  `/redis/`. `pogi env` and `pogi tf --cloud gcp` add it for you. See
  [Connect your tools](docs/how-to/connect-your-tools.md#google-cloud).
- **Cloud Billing accounts (Google Cloud).** pogi has one open billing account, `000000-000000-000000`
  ("My Billing Account"). `gcloud billing accounts list`, `gcloud billing projects link` and `unlink`,
  Terraform's `google_billing_account` data source and `google_project.billing_account` work against it.
  A new project has no billing account until you link one, as in Google Cloud.
- **BigQuery Storage Read API.** pandas' `to_dataframe` and the Go client's `EnableStorageReadClient` now read
  tables through it, over gRPC on pogi's port. A read session takes selected fields, a row restriction (this
  runs on DuckDB, so it needs Docker) and one or more streams, and answers with Arrow record batches.
- **DynamoDB PartiQL.** `ExecuteStatement`, `BatchExecuteStatement` and `ExecuteTransaction` run `SELECT`, `INSERT`,
  `UPDATE` and `DELETE`, with `?` parameters, nested paths, `NextToken` paging and `RETURNING`. A bad statement, a
  failed condition or a duplicate key gets DynamoDB's error.
- **Aurora DSQL clusters you can connect to.** With Docker, each cluster is a real PostgreSQL 16. Connect on pogi's
  own port over TLS, as `admin`, with a token from `aws dsql generate-db-connect-admin-auth-token` as the password.
- **Route 53 private zones answer DNS.** EC2 instances, ECS tasks, Lambda functions and Batch jobs that pogi runs in
  a VPC resolve names from the private hosted zones of that VPC. Other names go to the host's resolver, and the
  host's own DNS is not changed. `AssociateVPCWithHostedZone`, `DisassociateVPCFromHostedZone` and
  `ListHostedZonesByVPC` are new.
- **CodeDeploy ECS blue/green.** A deployment starts a replacement task set, moves the load balancer listener's
  traffic all at once, by canary or linearly, runs the lifecycle hooks, then ends the original tasks. A failed hook,
  an alarm or a stop with rollback puts traffic back. ECS services on the `CODE_DEPLOY` controller have task sets.
- **Service Quotas defaults.** `GetAWSDefaultServiceQuota`, `GetServiceQuota`, `ListServiceQuotas`,
  `ListAWSDefaultServiceQuotas` and `ListServices` answer from 73 default quotas for 13 services, each taken from an
  AWS documentation page.

### Removed

- **Amazon CodeGuru Reviewer.** AWS stopped taking new customers for it on November 7, 2025, and pogi lists only
  products that are open to new customers.
- **Azure Database for MariaDB.** Microsoft retired it in September 2025.

## [0.1.0] - 2026-10-17

The first release. pogi is one Go binary that emulates AWS, Google Cloud and Azure on one port
(7644), with a CLI, a terminal UI and a web console. It starts in about 25 ms and uses about 64 MB
at idle ([how we measured](docs/reference/benchmarks.md)).

### Added

- **181 services**: 131 AWS, 26 Google Cloud and 24 Azure.
  [docs/reference/coverage.md](docs/reference/coverage.md) lists each one, what it does and what
  it does not do.
  - AWS: S3, SQS, SNS, DynamoDB, Lambda, API Gateway, Step Functions, EventBridge, CloudFormation
    and the CDK, IAM, KMS, Secrets Manager, ECS, EKS, RDS and many more. 70 of them come from the
    botocore API models ([docs/reference/aws-long-tail.md](docs/reference/aws-long-tail.md)).
  - Google Cloud: Cloud Storage, Pub/Sub, Firestore, BigQuery, Cloud Run, Cloud Functions, Cloud
    SQL, Kubernetes Engine, Compute Engine and more.
  - Azure: Blob, Queue and Table Storage, Cosmos DB, Key Vault, Service Bus, Event Hubs, Functions,
    Azure SQL, Kubernetes Service, Virtual Machines and more. Azure Storage also listens on
    Azurite's ports, 10000-10002.
- **Works with the tools you already use**: the AWS, Google Cloud and Azure SDKs and CLIs,
  Terraform and the CDK. `pogi tf` prints a Terraform provider override and `pogi env` prints the
  SDK settings.
- **LocalStack compatibility**: the `/_localstack/health` and `/_localstack/init` endpoints, init
  hooks, the `Ready.` log line and the `SERVICES`, `PERSISTENCE`, `DEBUG`, `DEFAULT_REGION` and
  `GATEWAY_LISTEN` variables. `--port 4566` keeps the old endpoint. See
  [docs/how-to/migrate-from-localstack.md](docs/how-to/migrate-from-localstack.md).
- **Real engines in containers** when Docker or Podman is running: databases, caches, Kafka,
  OpenSearch, Kubernetes (EKS, GKE and AKS on k3s), container services and VMs. Without Docker those
  resources are kept as metadata only. pogi also runs inside a container with the Docker socket mounted.
- **State that survives restarts**: storage modes `memory`, `hybrid`, `persistent` and `wal`, set
  for all services or per service. `persistent` and `wal` keep every acknowledged write through a
  `kill -9`. Named snapshots can be saved, loaded, exported and imported.
- **`pogi.yaml`** for settings, identities, seed resources, CloudFormation stacks and chaos rules,
  applied at start and after every reset.
- **Testing tools**: IAM enforcement (`--iam soft|strict`), optional SigV4 signature checks, chaos
  rules (errors and latency per service, operation or rate), and `aws-cn` and `aws-us-gov`
  partitions.
- **Input checks**: requests are checked against each API's own limits (lengths, ranges, patterns
  and allowed values), and unknown operations or resource types fail with the cloud's own error.
- **Clean shutdown**: on Ctrl-C or SIGTERM pogi stops what it started and prints the list. With
  saved state, its containers are stopped and come back on the next start. `pogi clean` removes
  containers and volumes left behind by a pogi that is gone.
- **Crash safety**: a panic in one request or background task is logged and answered with a 500 in
  the cloud's own error shape. pogi keeps running.
- **Safe on localhost**: pogi refuses requests that web pages on other sites send to it (cross-site
  requests and DNS rebinding). Uploads are limited to 10 MB per file (`--max-upload-mb`), and an
  upload that stalls for 30 seconds is closed. A local CA gives TLS and `*.localhost` hostnames.
- **For coding agents**: an MCP server (`pogi mcp`, or `/_pogi/mcp` over HTTP) with 22 tools, and
  `pogi agents init` to add a pogi brief to `AGENTS.md`.
- **Commands**: `start`, `tui`, `status`, `services`, `wait`, `config`, `env`, `aws`, `tf`,
  `kubeconfig gke`, `logs`, `ls`, `reset`, `clean`, `snapshot`, `chaos`, `lambda-sdks`, `cert`,
  `doctor`, `mcp`, `agents init` and `version`.
- **Install** with Homebrew on macOS (`brew install nrndev/tap/pogi`), `.deb` and `.rpm` packages
  on Linux, Scoop on Windows, Docker (`ghcr.io/nrndev/pogi`), `go install`, or a release archive
  for Linux, macOS and Windows on amd64 and arm64. The checksums and the image are signed with
  cosign, and the archives and packages carry GitHub build attestations ([how to check a download](docs/how-to/install.md)).

[Unreleased]: https://github.com/nrndev/pogi/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/nrndev/pogi/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/nrndev/pogi/releases/tag/v0.1.0

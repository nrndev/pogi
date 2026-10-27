<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/wordmark-dark.svg">
    <img src="docs/images/wordmark-light.svg" height="56" alt="pogi">
  </picture>
</p>

<h3 align="center">The whole cloud on your machine ☁️</h3>

<p align="center">
  AWS, Google Cloud and Azure in one small program, on one port.<br>
  Free, offline, no account.
</p>

<p align="center">
  <a href="docs/README.md">📖 Docs</a> ·
  <a href="#-install">📦 Install</a> ·
  <a href="CHANGELOG.md">📝 Changelog</a> ·
  <a href="https://pogi.nrnx.dev">🌐 Website</a>
</p>

<p align="center">
  <a href="https://github.com/nrndev/pogi/actions/workflows/preflight.yml"><img src="https://github.com/nrndev/pogi/actions/workflows/preflight.yml/badge.svg" alt="preflight"></a>
  <a href="https://github.com/nrndev/pogi/releases/latest"><img src="https://img.shields.io/github/v/release/nrndev/pogi" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/nrndev/pogi" alt="MIT license"></a>
  <a href="https://pkg.go.dev/github.com/nrndev/pogi"><img src="https://pkg.go.dev/badge/github.com/nrndev/pogi.svg" alt="Go reference"></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/nrndev/pogi"><img src="https://api.scorecard.dev/projects/github.com/nrndev/pogi/badge" alt="OpenSSF Scorecard"></a>
</p>

<p align="center">
  <img src="docs/images/demo.gif" width="880" alt="Typing pogi opens its terminal screen. Calls from the AWS, Google Cloud and Azure CLIs fill the Overview with the services in use and recent calls. The Requests tab lists all 14 calls to S3, SQS, SNS, DynamoDB, Cloud Storage, Pub/Sub and Blob Storage, each answering 200 or 201. The Flows tab shows the hand-offs between services, such as an SNS message delivered to an SQS queue.">
</p>

## 👋 What is pogi?

pogi runs AWS, Google Cloud and Azure on your laptop. Point your SDKs, the cloud CLIs, Terraform or the CDK at it, and they work the way they do against the real cloud.

- 💸 **No account, no bill.** Nothing leaves your machine.
- ⚡ **One program, one port.** Everything answers on `localhost:7644`, and pogi starts in about 30 ms.
- ☁️ **Three clouds.** No separate emulator for each one:

| Cloud | Services | With real behavior | Thin |
|---|--:|--:|--:|
| AWS | <!-- count:aws_services -->144<!-- /count --> | <!-- count:aws_real -->90<!-- /count --> | <!-- count:aws_thin -->54<!-- /count --> |
| Google Cloud | <!-- count:gcp_services -->108<!-- /count --> | <!-- count:gcp_real -->25<!-- /count --> | <!-- count:gcp_thin -->83<!-- /count --> |
| Azure | <!-- count:azure_services -->103<!-- /count --> | <!-- count:azure_real -->30<!-- /count --> | <!-- count:azure_thin -->73<!-- /count --> |
| **All** | **<!-- count:all_services -->355<!-- /count -->** | **<!-- count:all_real -->145<!-- /count -->** | **<!-- count:all_thin -->210<!-- /count -->** |

A **Thin** service keeps your resources and reads them back, but nothing runs behind it. See [every service](#-services).

> [!NOTE]
> pogi is new, at version 0.x. Flags, config keys and APIs may still change between releases. The [changelog](CHANGELOG.md) lists every change.

## ✨ Why pogi

- 🎯 **It behaves like the real thing.** pogi is tested with the official SDKs. Lambda runs Python and Node.js directly, Terraform and `cdk deploy` work, and services trigger each other as they do in the cloud: S3 to SQS, SNS to Lambda, Pub/Sub push, Event Grid and more.
- 🧪 **It's made for tests.** Reset everything with one command. Save and load snapshots. Make chosen calls fail or slow down. Keep state on disk or in memory. Run it in CI, or start it inside your Go tests.
- 🔁 **It's a drop-in for LocalStack.** It has the same health endpoint, init hooks and `Ready.` log line, and `--port 4566` keeps your old endpoint. See [Migrate from LocalStack](docs/how-to/migrate-from-localstack.md).
- 🔒 **It stays on your machine.** pogi listens on 127.0.0.1 only, refuses requests from other websites and never phones home.

## 🚀 Quick start

1. **Install pogi.** On macOS, with Homebrew. For Linux, Windows, Docker and Go, see [Install](#-install).

   ```sh
   brew install nrndev/tap/pogi
   ```

2. **Start it.** This opens the terminal screen (the TUI). Add `--headless` for plain logs instead.

   ```sh
   pogi
   ```

3. **Point your tools at it.** In a second terminal, this sets the endpoint and the test credentials your tools read.

   ```sh
   eval "$(pogi env)"
   ```

4. **Make something** with the CLIs you already have:

   ```sh
   aws s3 mb s3://demo
   gcloud storage buckets create gs://demo
   az storage container create -n demo
   ```

5. **Look inside.** Open the web console at <http://localhost:7644/_pogi/>. It shows your buckets and every call you made.

> [!TIP]
> Your own code needs nothing more. Only the endpoint and the credentials change, and `pogi env` sets both.

## 🖥️ The console

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/console-dark.jpg">
  <img src="docs/images/console-light.jpg" alt="The pogi web console's Home page: seven services in use across AWS, Google Cloud and Azure, each with its icon, request and error counts, a rough real-cloud cost, and a live list of calls.">
</picture>

While pogi runs, the web console at `http://localhost:7644/_pogi/` shows what your code did:

- 🔎 **Activity and Flows:** every call, and the chain of calls one request set off across services.
- 🗺️ **Map:** your resources and how they connect, with live traffic.
- 🔐 **IAM policy:** a least-privilege policy (IAM is the set of rules for who may call what), built from what each caller really did. Enforce it with `--iam soft` or `--iam strict`.
- 💰 **Cost:** a rough monthly estimate of what your setup would cost in the real clouds.
- 🏗️ **Terraform cost:** what a Terraform folder or plan would cost a month, plus a diagram of its resources and what a plan changes. Use `pogi cost ./infra` or the **Terraform** tab on the Cost page. pogi reads the files itself and never runs Terraform. Google Cloud prices are not included yet. See [Estimate Terraform cost](docs/how-to/estimate-terraform-cost.md).
- 💥 **Chaos and Snapshots:** make chosen calls fail or slow down, and save and load state.
- 🧰 **SQL editor, Secrets and Inbox:** query your databases, read your secrets, and see the email, SMS and push messages your apps sent.

## 🤖 Use it from your coding agent

pogi has a built-in MCP server. MCP is the protocol AI coding agents use to call tools, so agents such as Claude Code, Cursor and Codex can look inside your local cloud and drive it while they work, all without touching a real account.

Add it to Claude Code with one line. pogi must be running:

```sh
claude mcp add pogi -- pogi mcp
```

`pogi mcp --print-config` prints the setup for Cursor and Codex too. `pogi agents init` adds a short brief on using pogi to your project's AGENTS.md.

The server has 24 tools:

| To | An agent can |
|---|---|
| 👀&nbsp;**Look** | list resources and their details, read the request log, and open any request in full |
| 🐛&nbsp;**Debug** | check IAM decisions, peek at queued messages, read the email and SMS your app sent, and read function logs |
| 💲&nbsp;**Price** | price a Terraform folder or plan, and look up the sizes of a machine type |
| 🛠️&nbsp;**Act** | invoke a function, deploy or delete a CloudFormation stack, seed resources, and reset |
| 💥&nbsp;**Break** | save and load snapshots, and add or clear chaos rules |

Cloud calls still go through the normal SDKs and CLIs, so the agent tests your code the way you would. The [CLI reference](docs/reference/cli.md#pogi-mcp-run-the-mcp-server-for-ai-agents) lists every tool.

## 📦 Install

**🍎 macOS** with Homebrew:

```sh
brew install nrndev/tap/pogi
```

**🐧 Linux** (Debian, Ubuntu) with the `.deb` package. On Arm, use `arm64` in place of `amd64`:

```sh
curl -LO https://github.com/nrndev/pogi/releases/download/v0.2.0/pogi_0.2.0_linux_amd64.deb
sudo apt install ./pogi_0.2.0_linux_amd64.deb
```

Fedora, RHEL and Amazon Linux use the `.rpm` from the same place: `sudo dnf install ./pogi_0.2.0_linux_amd64.rpm`.

**🪟 Windows** with Scoop:

```powershell
scoop bucket add nrndev https://github.com/nrndev/scoop-bucket
scoop install nrndev/pogi
```

**🐳 Docker**, with nothing else to install. The image includes Python and Node.js, so functions run inside it. Ports 10000 to 10002 are for Azure Storage.

```sh
docker run --rm -p 127.0.0.1:7644:7644 -p 127.0.0.1:10000-10002:10000-10002 ghcr.io/nrndev/pogi
```

**🐹 Go**, version 1.27.3 or newer:

```sh
go install github.com/nrndev/pogi/cmd/pogi@latest
```

You can also download a binary for Linux, macOS or Windows, on Intel or Arm, from the [releases page](https://github.com/nrndev/pogi/releases). After installing, run `pogi doctor` to check your setup. [Install pogi](docs/how-to/install.md) has more detail.

## 🔌 Use it with

| Tool | How |
|---|---|
| AWS CLI and SDKs | `eval "$(pogi env)"`, or `pogi aws …`. [Connect your tools](docs/how-to/connect-your-tools.md#sdks-and-clis) |
| Terraform | `pogi tf > pogi_override.tf`. [Terraform](docs/how-to/connect-your-tools.md#terraform) |
| AWS CDK | `cdk bootstrap` and `cdk deploy`, no wrapper. [CDK](docs/how-to/connect-your-tools.md#cdk) |
| Google Cloud | Client libraries and `gcloud` read the variables `pogi env` sets. [Google Cloud](docs/how-to/connect-your-tools.md#google-cloud) |
| Azure | Azurite ports for storage, HTTPS for Cosmos DB and Key Vault. [Azure](docs/how-to/connect-your-tools.md#azure) |
| Go tests | Start pogi in-process from your tests. [Go tests](docs/how-to/connect-your-tools.md#go-tests) |
| Coding agents | `pogi mcp`, and `pogi agents init` for AGENTS.md. [Use it from your coding agent](#-use-it-from-your-coding-agent) |

## 📋 Services

Most services run inside pogi itself. The ones marked "with Docker running" start real software, such as Postgres, Redis or Kafka, in Docker (or any engine with the Docker API: Podman, Colima or OrbStack).

<details>
<summary><!-- count:total -->355 services: 144 AWS (90 with real behavior, 54 Thin), 108 Google Cloud (25 with real behavior, 83 Thin) and 103 Azure (30 with real behavior, 73 Thin)<!-- /count -->. Click to see them all.</summary>

<!-- services:start (generated from the registry and docs/reference/coverage.yaml by `go generate .`) -->
| Cloud | Services |
|---|---|
| **AWS** | S3, SQS, SNS, DynamoDB + Streams, Lambda, API Gateway v1 + v2, Step Functions, EventBridge + Scheduler, Kinesis / Firehose, CloudFormation, IAM, STS, KMS, Secrets Manager, CloudWatch Logs, CloudWatch Metrics, SES v1 + v2, Cognito user pools, AppSync, EventBridge Pipes, API Gateway WebSockets, Cognito identity pools, IoT Core, Cloud Map, CloudTrail, Fault Injection Service, CodeDeploy + CodePipeline, Organizations + SCPs, Verified Permissions, Resource Explorer, AppConfig, CloudFront, S3 Vectors, SES SMTP, Amplify, Polly, Shield, CodeCommit, Location, Keyspaces, FSx, Resource Groups, CodeStar Connections, X-Ray, DAX, IAM Identity Center, Security services, Transfer Family, DataSync, S3 Tables, AWS Backup, Config, Managed Prometheus, RUM, OAM, Cloud Control API, Beanstalk, EMR, MWAA, Flink, Lightsail, DMS, Lake Formation, Connect, Bedrock and the AI services, Cost services, ACM, Route 53, EC2 network, Tagging, AppFlow, MediaConvert, IVS, Security Lake, QuickSight, Amazon Managed Grafana, VPC Lattice, MediaLive, MediaPackage, GameLift, Kinesis Video Streams, DataZone, Data Exchange, Clean Rooms, Resilience Hub, Application Recovery Controller, Payment Cryptography, Private CA, AWS Direct Connect, Amazon WorkSpaces, Amazon WorkSpaces Secure Browser, Amazon AppStream 2.0, AWS Directory Service, AWS Signer, AWS Elastic Disaster Recovery, AWS Cloud WAN and Network Manager, AWS Device Farm, AWS License Manager, Firewall Manager, User Notifications, Compute Optimizer, Cost Optimization Hub, EC2 Image Builder, Storage Gateway, End User Messaging SMS and voice, Serverless Application Repository, Oracle Database@AWS, Aurora DSQL, and 14 more long-tail services generated from the AWS API models (see [docs/reference/aws-long-tail.md](docs/reference/aws-long-tail.md)); with Docker running: Systems Manager (SSM), RDS / ElastiCache, ECR, ECS, ELB v2, EC2 transit gateways, flow logs, hosts and images, EKS, EC2 instances, Auto Scaling + Application Auto Scaling, Batch, CodeBuild, RDS extras, ElastiCache users / MemoryDB, MSK, Amazon MQ, OpenSearch Service, Glue + Athena, Redshift + Data API + Serverless, Timestream for InfluxDB |
| **Google Cloud** | Cloud Storage, Pub/Sub, Firestore (Native), Firestore (Datastore mode), Secret Manager, Cloud Logging, Cloud Monitoring, Cloud Tasks, Cloud Scheduler, Eventarc, IAM, IAM Credentials, OAuth2, STS, Resource Manager, Service Usage, Cloud KMS, Firebase Auth, Long-running operations, Workflows, Cloud DNS, Filestore, Certificate Manager, Cloud Bigtable, Looker, Certificate Authority Service, Cloud Healthcare, Dataplex, BigQuery Data Transfer, Storage Transfer, Cloud Build, Cloud Deploy, API Keys, Service Directory, Binary Authorization, Container Analysis, Essential Contacts, Organization Policy, Cloud Asset Inventory, Dataproc, Cloud Composer, Dataflow, Memorystore for Memcached, Serverless VPC Access, Network Connectivity Center, AlloyDB, Datastream, Cloud Load Balancing, Cloud Armor, Analytics Hub, BigLake, Cloud Data Fusion, Dataform, Dataproc Metastore, Database Migration Service, Memorystore for Valkey, Oracle Database@Google Cloud, Backup and DR Service, NetApp Volumes, Parallelstore, Managed Lustre, Transcoder API, Apigee, API hub, App Hub, Application Integration, Integration Connectors, Cloud Endpoints, Developer Connect, Secure Source Manager, Parameter Manager, Cloud Billing budgets, Cloud Billing accounts, Migration Center, Blockchain Node Engine, License Manager, Firebase App Check, Firebase App Hosting, Firebase Data Connect, Network Intelligence Center, Cloud NGFW, Cloud Service Mesh, Cloud Domains, VMware Engine, Google Distributed Cloud, GKE Multi-Cloud, Backup for GKE, App Engine, Cloud Workstations, Cluster Director, VM Manager, Cloud Quotas, Infrastructure Manager, VPC Service Controls, Managed Microsoft AD, Assured Workloads, Chrome Enterprise Premium, Google Security Operations, Cloud Identity, Cloud IDS, Compliance Manager, Sensitive Data Protection, Identity-Aware Proxy, Privileged Access Manager, reCAPTCHA, Security Command Center, Public CA; with Docker running: Cloud SQL, Cloud Run, BigQuery, Cloud Functions, Managed Kafka, Kubernetes Engine, Compute Engine, Artifact Registry, Memorystore for Redis, Cloud Spanner |
| **Azure** | Blob Storage, Queue Storage, Table Storage, Cosmos DB (NoSQL), Key Vault, Service Bus, Event Hubs, Event Grid, App Configuration, SignalR, Communication Services email, Resource Manager, Entra ID, Managed Identity, Graph, Management planes (ARM), Azure Monitor, Virtual Network, API Management, Azure Files, Data Lake Storage Gen2, DNS, Policy, Logic Apps, Front Door, Application Gateway, Load Balancer, Firewall, Bastion, Traffic Manager, Private Link, Virtual WAN, Data Factory, Azure Batch, Azure Managed Grafana, Cognitive Services, Databricks, AI Search, Synapse, Data Explorer, Stream Analytics, Static Web Apps, Web PubSub, Notification Hubs, Relay, IoT Hub, Azure Maps, Automation, Recovery Services, Azure Arc, Azure Local, Azure VMware Solution, Azure Red Hat OpenShift, Kubernetes Fleet Manager, Service Fabric, Azure Virtual Desktop, DevTest Labs, Dev Box, Azure Load Testing, Managed DevOps Pools, Center for SAP solutions, Network Watcher, DDoS Protection, Virtual Network Manager, Route Server, ExpressRoute, VPN Gateway, Web Application Firewall, Application Gateway for Containers, NetApp Files, Azure Managed Lustre, Elastic SAN, Storage Mover, Azure File Sync, Data Share, Analysis Services, HDInsight, Power BI Embedded, Fabric capacities, Managed Redis, Oracle Database@Azure, Health Data Services, Digital Twins, IoT Hub Device Provisioning, Microsoft Entra Domain Services, Microsoft Defender for Cloud, Microsoft Sentinel, Confidential Ledger, Trusted Signing, Azure Lighthouse, Azure Advisor, Cost Management, Azure Managed Applications, Microsoft Purview, Chaos Studio; with Docker running: Azure Functions, Azure SQL, PostgreSQL, MySQL, Cache for Redis, Kubernetes Service, Container Registry, Container Instances, Container Apps, Virtual Machines, Cosmos DB for MongoDB, App Service |
<!-- services:end -->

</details>

The [coverage page](docs/reference/coverage.md) says what each service does and what it doesn't do yet.

## ⚠️ What pogi doesn't do

- ☁️ **It's not the real cloud.** Some services have real behavior wired to other services. A Thin service stores your resources and reads them back, and nothing runs behind it.
- 🧪 **It's built for tests and local development.** It keeps data in memory by default and limits uploads to 10 MB (raise that with `--max-upload-mb`). Don't run it as a server for other people.
- 🔑 **It never calls the real clouds,** so never give it real credentials. `pogi env` sets test ones for you.

## 📚 Learn more

- 📖 **Docs:** [tutorials, how-to guides, reference and explanation](docs/README.md). New here? Start with the [first run tutorial](docs/tutorials/first-run.md), or read the [FAQ](docs/explanation/faq.md).
- 🤝 **Contributing:** bug reports, ideas and pull requests are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers building, testing, adding a service and running the security scans.
- 🛡️ **Security:** report vulnerabilities privately, as [SECURITY.md](SECURITY.md) describes.
- ⚖️ **License:** [MIT](LICENSE). Some AWS services are generated from the AWS API models, which are under the Apache 2.0 license ([NOTICE](NOTICE)).

## Third-party icons

The console and the Terraform diagram show the official AWS, Azure and Google Cloud icons. They are in `internal/web/icons/`, unchanged, and they are **not** under the MIT license: each provider's terms apply. See [internal/web/icons/NOTICE](internal/web/icons/NOTICE). A service with no official icon shows one of pogi's own plain glyphs.

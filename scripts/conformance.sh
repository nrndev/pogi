#!/bin/sh
# Runs real Terraform (aws and google providers) and CDK projects against a fresh pogi:
#   terraform apply → plan (must show no changes) → destroy
#   cdk bootstrap → deploy → destroy
# Needs terraform, node/npm and python3; downloads providers and packages.
#
#   scripts/conformance.sh [block ...]     no arguments runs every block
#
# Blocks: aws, compute (ECR, ECS behind an ALB, Auto Scaling), google, azurerm (needs Docker), longtail, cdk.
# Each examples/terraform-<google|azure|aws>-thin-<group>/ folder is a block too, <google|azurerm|aws>-<group>,
# so a failure names its group; google-thin, azurerm-thin and aws-thin run every group of that cloud.
# CI runs each block in its own job, side by side.
set -eu
blocks=${*:-aws compute google azurerm longtail google-thin azurerm-thin aws-thin cdk}
want() { case " $blocks " in *" $1 "*) return 0 ;; esac; return 1; }
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
port=${POGI_PORT:-4599}
region=${REGION:-us-east-1} # Terraform's; us-gov-west-1 and cn-north-1 cover the other partitions
ep=http://localhost:$port
# pid is unset until pogi starts (a failed build exits before that), and pogi may already be gone, so neither may
# stop the cleanup.
trap '[ -z "${pid:-}" ] || kill "$pid" 2>/dev/null || true; rm -rf "$work"' EXIT

# nodrift <terraform|tfd>: a second plan must find nothing to change. On drift, print what it wanted to change.
nodrift() { "$1" plan -detailed-exitcode -input=false -no-color > "$work/plan.txt" 2>&1 || { cat "$work/plan.txt" >&2; return 1; }; }

go build -o "$work/pogi" "$root/cmd/pogi"
"$work/pogi" start --headless --quiet --port "$port" --data-dir "$work/data" --iam soft &
pid=$!
until curl -fs "$ep/_localstack/health" >/dev/null; do sleep 0.2; done
"$work/pogi" lambda-sdks --data-dir "$work/data" >/dev/null
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1 AWS_ENDPOINT_URL=$ep

if want aws; then
echo "== terraform"
cp -R "$root/examples/terraform" "$work/tf"
"$work/pogi" tf --endpoint "$ep" --region "$region" > "$work/tf/pogi_override.tf"
(cd "$work/tf" && terraform init -input=false >/dev/null && terraform apply -auto-approve -input=false >/dev/null \
  && terraform output arns && nodrift terraform && terraform destroy -auto-approve -input=false >/dev/null)
echo "terraform ($region): apply, no-drift plan and destroy passed"
fi

if want compute; then

echo "== terraform: ECR, ECS behind an ALB, Auto Scaling"
cp -R "$root/examples/terraform-compute" "$work/tfc"
"$work/pogi" tf --endpoint "$ep" --region "$region" > "$work/tfc/pogi_override.tf"
(cd "$work/tfc" && terraform init -input=false >/dev/null && terraform apply -auto-approve -input=false >/dev/null \
  && if docker info >/dev/null 2>&1; then # the service's nginx tasks answer through the load balancer
    curl -fs -H "Host: $(terraform output -raw url | cut -d/ -f3)" "$ep/" | grep -q nginx; fi \
  && nodrift terraform && terraform destroy -auto-approve -input=false >/dev/null)
echo "terraform compute ($region): apply, ALB → ECS, no-drift plan and destroy passed"
fi

# google_tf <example folder> <work folder> <label>: apply, a plan with no changes, and destroy, with the google
# provider on the host.
google_tf() {
  echo "== terraform: $3"
  cp -R "$root/examples/$1" "$work/$2"
  # docker-*.tf hold the resources that run a container (Spanner and Bigtable emulators, Redis): left out without Docker
  docker info >/dev/null 2>&1 || { rm -f "$work/$2"/docker-*.tf; echo "(Docker is not running: docker-*.tf left out)"; }
  "$work/pogi" tf --cloud gcp --endpoint "$ep" > "$work/$2/pogi_override.tf"
  export BIGTABLE_EMULATOR_HOST=localhost:$port # the provider's Bigtable client takes the address from here, not from the custom endpoint
  (cd "$work/$2" && terraform init -input=false >/dev/null && terraform apply -auto-approve -input=false >/dev/null \
    && nodrift terraform && terraform destroy -auto-approve -input=false >/dev/null) \
    || { echo "terraform $3: FAILED" >&2; exit 1; }
  echo "terraform $3: apply, no-drift plan and destroy passed"
}
if want google; then google_tf terraform-google tfg "google provider"; fi

# azurerm_tf <example folder> <work folder> <label>: the same with the azurerm provider, in a container.
# azurerm reads every URL from pogi's metadata endpoint, over TLS. Terraform on the host would need pogi's CA
# in the system's trust store (the macOS keychain: not something to change), so it runs in a container
# that trusts the CA through SSL_CERT_FILE and reaches pogi at host.docker.internal. The *.localhost names
# the example's Key Vault and storage account have are mapped to the host as well.
azurerm_tf() {
  if ! docker info >/dev/null 2>&1; then
    echo "== terraform: $3 skipped (Docker is not running)"
    return 0
  fi
  echo "== terraform: $3 (in a container)"
  cp -R "$root/examples/$1" "$work/$2"
  "$work/pogi" tf --cloud azure --endpoint "$ep" > "$work/$2/pogi_override.tf"
  cache=${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}
  mkdir -p "$cache"
  # Docker Desktop and other VM engines forward host.docker.internal to this machine's loopback. A Linux
  # engine does not reach 127.0.0.1 through its bridge, so there the container shares the host's network.
  # It also runs as this user there, so the files it writes can be cleaned up afterwards.
  gw=host-gateway net=
  [ "$(uname -s)" = Linux ] && gw=127.0.0.1 net="--network=host --user $(id -u):$(id -g) -e HOME=/tmp"
  tfdir=$work/$2
  tfd() {
    docker run --rm $net -v "$tfdir":/work -w /work --add-host host.docker.internal:$gw \
      --add-host pogi-tf-kv.vault.localhost:$gw --add-host pogitfstore.blob.localhost:$gw \
      --add-host pogitfstore.queue.localhost:$gw --add-host pogitfstore.table.localhost:$gw \
      --add-host pogitflake.file.localhost:$gw --add-host pogitflake.dfs.localhost:$gw --add-host pogitflake.blob.localhost:$gw \
      --add-host a2dhdistore.blob.localhost:$gw --add-host a2dhdistore.queue.localhost:$gw --add-host a2dhdistore.table.localhost:$gw --add-host a2dhdistore.file.localhost:$gw \
      -v "$work/data/certs/ca.pem":/pogi-ca.pem -e SSL_CERT_FILE=/pogi-ca.pem \
      -v "$cache":/cache -e TF_PLUGIN_CACHE_DIR=/cache -e TF_IN_AUTOMATION=1 hashicorp/terraform "$@" -input=false
  }
  # A failing command inside an && list doesn't stop the script under set -e, so say so and stop here.
  (tfd init >/dev/null && tfd apply -auto-approve >/dev/null && nodrift tfd && tfd destroy -auto-approve >/dev/null) \
    || { echo "terraform $3: FAILED" >&2; exit 1; }
  echo "terraform $3: apply, no-drift plan and destroy passed"
}
if want azurerm; then azurerm_tf terraform-azure tfa "azurerm provider"; fi

# aws_tf <example folder> <work folder> <label>: the same with the aws provider, on the host.
aws_tf() {
  echo "== terraform: $3"
  cp -R "$root/examples/$1" "$work/$2"
  "$work/pogi" tf --endpoint "$ep" --region "$region" > "$work/$2/pogi_override.tf"
  (cd "$work/$2" && terraform init -input=false >/dev/null && terraform apply -auto-approve -input=false >/dev/null \
    && nodrift terraform && terraform destroy -auto-approve -input=false >/dev/null) \
    || { echo "terraform $3: FAILED" >&2; exit 1; }
  echo "terraform $3 ($region): apply, no-drift plan and destroy passed"
}
if want longtail; then aws_tf terraform-longtail tfl "long-tail services (generated engine)"; fi

# The Thin groups, one block per examples/terraform-<cloud>-thin-<group>/ folder.
for cloud in google azure aws; do
  block=$cloud
  [ $cloud = azure ] && block=azurerm
  for dir in "$root"/examples/terraform-$cloud-thin-*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    group=${name#terraform-$cloud-thin-}
    if want "$block-$group" || want "$block-thin"; then
      "${block}_tf" "$name" "t-$block-$group" "$block Thin, $group"
    fi
  done
done

if want cdk; then

echo "== cdk"
# npm ci installs exactly what examples/cdk/package-lock.json pins (Dependabot keeps it current).
cp -R "$root/examples/cdk" "$work/cdk"
(cd "$work/cdk" && npm ci --no-audit --no-fund >/dev/null && npx cdk bootstrap aws://000000000000/us-east-1 >/dev/null \
  && npx cdk deploy --require-approval never >/dev/null && npx cdk destroy --force >/dev/null)
echo "cdk: bootstrap, deploy and destroy passed"
fi

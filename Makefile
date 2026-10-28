# Local builds. Publishing is the release workflow's job (goreleaser on a pushed tag); nothing here uploads.
#   make test            vet and test with the race detector (make test G=<group>: one CI test group, for example aws-a-f; see scripts/ci.sh groups)
#   make ci              every CI check on this machine (scripts/ci.sh)
#   make lint            golangci-lint
#   make gate            the full pre-release gate: race tests with Docker on, then conformance
#   make generate        rewrite docs/reference/coverage.md and the README's Services table
#   make release         archives and checksums.txt for 6 platforms in $(DIST)
#   make docker-release  the release image from the linux binary of this machine's architecture
VERSION ?= 0.2.0
DIST    ?= dist
PLATFORMS ?= linux/amd64 linux/arm64 darwin/amd64 darwin/arm64 windows/amd64 windows/arm64
LDFLAGS := -s -w -X github.com/nrndev/pogi.Version=$(VERSION)

.PHONY: test ci lint gate generate release docker-release

test:
ifdef G
	scripts/ci.sh test $(G)
else
	go vet ./...
	go test -race -count=1 ./...
endif

ci:
	scripts/ci.sh

lint:
	scripts/ci.sh lint

gate:
	scripts/ci.sh gate

generate:
	go generate .

release:
	rm -rf $(DIST) && mkdir -p $(DIST)
	set -e; for p in $(PLATFORMS); do \
	  os=$${p%/*}; arch=$${p#*/}; exe=pogi; [ $$os = windows ] && exe=pogi.exe; \
	  name=pogi_$(VERSION)_$${os}_$$arch; dir=$(DIST)/$$name; \
	  mkdir -p $$dir; \
	  CGO_ENABLED=0 GOOS=$$os GOARCH=$$arch go build -trimpath -ldflags "$(LDFLAGS)" -o $$dir/$$exe ./cmd/pogi; \
	  cp LICENSE README.md $$dir/; \
	  if [ $$os = linux ]; then mkdir -p $(DIST)/docker/linux/$$arch && cp $$dir/$$exe $(DIST)/docker/linux/$$arch/pogi; fi; \
	  if [ $$os = windows ]; then (cd $(DIST) && zip -qr $$name.zip $$name); else tar -C $(DIST) -czf $(DIST)/$$name.tar.gz $$name; fi; \
	  rm -rf $$dir; \
	done
	cd $(DIST) && (sha256sum pogi_* 2>/dev/null || shasum -a 256 pogi_*) > checksums.txt
	@cat $(DIST)/checksums.txt

# The context of Dockerfile.release is what goreleaser gives it: <os>/<arch>/pogi and the entrypoint.
docker-release: release
	mkdir -p $(DIST)/docker/scripts && cp scripts/docker-entrypoint.sh $(DIST)/docker/scripts/
	docker build -f Dockerfile.release --build-arg TARGETPLATFORM=linux/$(shell go env GOARCH) -t pogi:$(VERSION) $(DIST)/docker

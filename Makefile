BIN := bin
DIST := dist
NAME := go-xgettext
ifeq ($(OS), Windows_NT)
	EXECUTABLE := $(NAME).exe
	UNAME := Windows
else
	EXECUTABLE := $(NAME)
	UNAME := $(shell uname -s)
endif

GOBUILD ?= go build

SOURCES ?= $(shell find . -name "*.go" -type f -not -path "./node_modules/*")

TAGS ?=

ifndef OUTPUT
	ifneq ($(DRONE_TAG),)
		OUTPUT ?= $(subst v,,$(DRONE_TAG))
	else
		OUTPUT ?= testing
	endif
endif


.PHONY: clean
clean:
	go clean -i ./...
	rm -rf $(BIN) $(DIST) coverage.out


.PHONY: fmt
fmt:
	gofmt -s -w $(SOURCES)

.PHONY: generate
generate:
	go generate

.PHONY: build-all
build-all: build build-debug

.PHONY: build
build: $(BIN)/$(EXECUTABLE)

.PHONY: build-debug
build-debug: $(BIN)/$(EXECUTABLE)-debug

$(BIN)/$(EXECUTABLE): $(SOURCES)
	$(GOBUILD) -v -tags '$(TAGS)' -ldflags '$(LDFLAGS)' -o $@ ./go-xgettext

$(BIN)/$(EXECUTABLE)-debug: $(SOURCES)
	$(GOBUILD) -v -tags '$(TAGS)' -ldflags '$(DEBUG_LDFLAGS)' -gcflags '$(GCFLAGS)' -o $@ ./go-xgettext

.PHONY: test
test:
	@go test -v -tags '$(TAGS)' -coverprofile coverage.out ./go-xgettext

.PHONY: release
release: release-dirs release-binaries release-copy release-check

.PHONY: release-dirs
release-dirs:
	@mkdir -p $(DIST)/binaries $(DIST)/release

.PHONY: release-binaries
release-binaries: release-dirs
	GOOS=linux \
	GOARCH=amd64 \
	go build \
		-o '$(DIST)/binaries/$(EXECUTABLE)-$(OUTPUT)-linux-amd64' \
		./go-xgettext/

	GOOS=linux \
	GOARCH=arm64 \
	go build \
		-o '$(DIST)/binaries/$(EXECUTABLE)-$(OUTPUT)-linux-arm64' \
		./go-xgettext/
	
	GOOS=darwin \
	GOARCH=amd64 \
	go build \
		-o '$(DIST)/binaries/$(EXECUTABLE)-$(OUTPUT)-darwin-amd64' \
		./go-xgettext/

	GOOS=darwin \
	GOARCH=arm64 \
	go build \
		-o '$(DIST)/binaries/$(EXECUTABLE)-$(OUTPUT)-darwin-arm64' \
		./go-xgettext/


.PHONY: release-copy
release-copy:
	$(foreach file,$(wildcard $(DIST)/binaries/go-xgettext-*),cp $(file) $(DIST)/release/$(notdir $(file));)

.PHONY: release-check
release-check:
	cd $(DIST)/release; $(foreach file,$(wildcard $(DIST)/release/go-xgettext-*),sha256sum $(notdir $(file)) > $(notdir $(file)).sha256;)

.PHONY: release-finish
release-finish: release-copy release-check

HARDWARE = $(shell uname -m)
SYSTEM_NAME  = $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH = $(shell dpkg --print-architecture)
SHFMT_VERSION = 3.0.2
XUNIT_TO_GITHUB_VERSION = 0.3.0
XUNIT_READER_VERSION = 0.1.0


bats:
ifeq ($(SYSTEM_NAME),darwin)
ifneq ($(shell bats --version >/dev/null 2>&1 ; echo $$?),0)
	brew install bats-core
endif
else
	git clone https://github.com/bats-core/bats-core.git /tmp/bats
	cd /tmp/bats && sudo ./install.sh /usr/local
	rm -rf /tmp/bats
endif

shellcheck:
ifneq ($(shell shellcheck --version >/dev/null 2>&1 ; echo $$?),0)
ifeq ($(SYSTEM_NAME),darwin)
	brew install shellcheck
else
ifeq ($(ARCH),arm64)
  sudo add-apt-repository 'deb http://ports.ubuntu.com/ubuntu-ports jammy-backports main restricted universe multiverse'
else
  sudo add-apt-repository 'deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse'
endif
	sudo rm -rf /var/lib/apt/lists/* && sudo apt-get clean
	sudo apt-get update -qq && sudo apt-get install -qq -y shellcheck
endif
endif

shfmt:
ifneq ($(shell shfmt --version >/dev/null 2>&1 ; echo $$?),0)
ifeq ($(shfmt),Darwin)
	brew install shfmt
else
	wget -qO /tmp/shfmt https://github.com/mvdan/sh/releases/download/v$(SHFMT_VERSION)/shfmt_v$(SHFMT_VERSION)_linux_amd64
	chmod +x /tmp/shfmt
	sudo mv /tmp/shfmt /usr/local/bin/shfmt
endif
endif

readlink:
ifeq ($(shell uname),Darwin)
ifeq ($(shell greadlink > /dev/null 2>&1 ; echo $$?),127)
	brew install coreutils
endif
	ln -nfs `which greadlink` tests/bin/readlink
endif

ci-dependencies: shellcheck bats readlink

lint-setup:
	@mkdir -p tmp/test-results/shellcheck tmp/shellcheck
	@find . -not -path '*/\.*' -not -path './tmp/*' -type f | xargs file | grep text | awk -F ':' '{ print $$1 }' | xargs head -n1 | egrep -B1 "bash" | grep "==>" | awk '{ print $$2 }' > tmp/shellcheck/test-files
	@cat tests/shellcheck-exclude | sed -n -e '/^# SC/p' | cut -d' ' -f2 | paste -d, -s - > tmp/shellcheck/exclude

lint: lint-setup
	# these are disabled due to their expansive existence in the codebase. we should clean it up though
	@cat tests/shellcheck-exclude | sed -n -e '/^# SC/p'
	@echo linting...
	@cat tmp/shellcheck/test-files | xargs shellcheck -e $(shell cat tmp/shellcheck/exclude) > tmp/shellcheck-output.log 2>&1; \
	EXIT_CODE=$$?; \
	tests/shellcheck-to-junit --output tmp/test-results/shellcheck/results.xml --files tmp/shellcheck/test-files --exclude $(shell cat tmp/shellcheck/exclude) < tmp/shellcheck-output.log; \
	if [ $$EXIT_CODE -ne 0 ]; then \
		echo "❌ Shellcheck found violations"; \
		cat tmp/shellcheck-output.log; \
		exit $$EXIT_CODE; \
	fi

unit-tests:
	@echo running integration tests...
	@mkdir -p tmp/test-results
	@if command -v dokku >/dev/null 2>&1; then \
		echo "Running integration tests against local Dokku..."; \
		set -e; \
		if ! scripts/test-integration.sh; then \
			echo "❌ Integration tests failed"; \
			echo "💡 Tip: For reliable testing, use: make docker-test"; \
			echo "💡 Local testing requires full Dokku installation with proper permissions"; \
			exit 1; \
		fi; \
		echo "✅ Integration tests passed"; \
	else \
		echo "No local Dokku found - integration tests skipped"; \
		echo "This is normal for CI environments without Dokku installed"; \
		echo "Integration tests can be run with: make docker-test"; \
	fi

tmp/xunit-reader:
	mkdir -p tmp
	curl -o tmp/xunit-reader.tgz -sL https://github.com/josegonzalez/go-xunit-reader/releases/download/v$(XUNIT_READER_VERSION)/xunit-reader_$(XUNIT_READER_VERSION)_$(SYSTEM_NAME)_$(HARDWARE).tgz
	tar xf tmp/xunit-reader.tgz -C tmp
	chmod +x tmp/xunit-reader

setup:
	bash tests/setup.sh
	$(MAKE) ci-dependencies

test: lint unit-tests

docker-test:
	@echo "Running integration tests in Docker container..."
	./tests/integration/docker-orchestrator.sh --direct

docker-test-clean:
	@echo "Cleaning up Docker test environment..."
	docker-compose -f tests/docker/docker-compose.yml down --volumes --remove-orphans
	docker rmi $$(docker images -q docker_test-runner) 2>/dev/null || true

report: tmp/xunit-reader
	tmp/xunit-reader -p 'tmp/test-results/bats/*.xml'
	tmp/xunit-reader -p 'tmp/test-results/shellcheck/*.xml'

.PHONY: clean
clean:
	rm -f README.md

.PHONY: generate
generate: clean README.md

.PHONY: README.md
README.md:
	bin/generate

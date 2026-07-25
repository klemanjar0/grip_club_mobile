# Grip Club Mobile — common tasks.
#
#   make                     list every target
#   make run-dev             run the dev flavor in debug
#   make run-dev DEVICE=...  pick a device (see `make devices`)
#   make run-dev API_URL=... point the dev flavor at another backend
#   make verify              analyze + test
#
# Every run/build target passes the three flags that must always agree: the
# native flavor, the Dart entrypoint and the matching env file.

FLUTTER ?= flutter
DEVICE ?=

# env/dev.json points at http://localhost:8080, which the Android emulator
# cannot reach — it sees the host as 10.0.2.2. A later --dart-define wins over
# --dart-define-from-file, so this overrides the single key:
#
#   make run-dev API_URL=http://10.0.2.2:8080/api/v1
API_URL ?=

# Expands to nothing when DEVICE is unset, letting Flutter prompt as usual.
DEVICE_ARG := $(if $(DEVICE),-d $(DEVICE),)
API_URL_ARG := $(if $(API_URL),--dart-define=API_BASE_URL=$(API_URL),)

DEV_FLAGS  := --flavor dev  -t lib/main_dev.dart  --dart-define-from-file=env/dev.json $(API_URL_ARG)
PROD_FLAGS := --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json

.DEFAULT_GOAL := help

##@ General

.PHONY: help
help: ## List available targets
	@awk 'BEGIN {FS = ":.*##"} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)} \
		/^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' \
		$(MAKEFILE_LIST)
	@printf "\nOverride the device with DEVICE=<id>, e.g. make run-dev DEVICE=chrome\n"
	@printf "Override the dev backend with API_URL=<url>, e.g. API_URL=http://10.0.2.2:8080/api/v1\n\n"

.PHONY: setup
setup: ## Fetch dependencies
	$(FLUTTER) pub get

.PHONY: devices
devices: ## List connected devices and simulators
	$(FLUTTER) devices

.PHONY: doctor
doctor: ## Check the local toolchain
	$(FLUTTER) doctor -v

.PHONY: outdated
outdated: ## Show dependencies with newer versions
	$(FLUTTER) pub outdated

##@ Run

.PHONY: run-dev
run-dev: ## Run dev flavor (debug)
	$(FLUTTER) run $(DEVICE_ARG) $(DEV_FLAGS)

.PHONY: run-dev-profile
run-dev-profile: ## Run dev flavor (profile)
	$(FLUTTER) run $(DEVICE_ARG) --profile $(DEV_FLAGS)

.PHONY: run-prod
run-prod: ## Run prod flavor (debug)
	$(FLUTTER) run $(DEVICE_ARG) $(PROD_FLAGS)

.PHONY: run-prod-release
run-prod-release: ## Run prod flavor (release)
	$(FLUTTER) run $(DEVICE_ARG) --release $(PROD_FLAGS)

##@ Quality

.PHONY: verify
verify: analyze test ## Analyze and test — run before pushing

.PHONY: analyze
analyze: ## Run the analyzer
	$(FLUTTER) analyze

.PHONY: test
test: ## Run unit tests
	$(FLUTTER) test

.PHONY: coverage
coverage: ## Run tests and write coverage/lcov.info
	$(FLUTTER) test --coverage

.PHONY: format
format: ## Format lib/ and test/
	dart format lib test

.PHONY: format-check
format-check: ## Fail if anything is unformatted (for CI)
	dart format --output=none --set-exit-if-changed lib test

##@ Android builds

.PHONY: apk-dev
apk-dev: ## Build dev APK (debug)
	$(FLUTTER) build apk --debug $(DEV_FLAGS)

.PHONY: apk-dev-release
apk-dev-release: ## Build dev APK (release)
	$(FLUTTER) build apk --release $(DEV_FLAGS)

.PHONY: apk-prod
apk-prod: ## Build prod APK (release)
	$(FLUTTER) build apk --release $(PROD_FLAGS)

.PHONY: bundle-prod
bundle-prod: ## Build prod App Bundle (release) for Play
	$(FLUTTER) build appbundle --release $(PROD_FLAGS)

##@ iOS builds

.PHONY: ios-dev
ios-dev: ## Build dev iOS app (release, unsigned)
	$(FLUTTER) build ios --release --no-codesign $(DEV_FLAGS)

.PHONY: ios-prod
ios-prod: ## Build prod iOS app (release, unsigned)
	$(FLUTTER) build ios --release --no-codesign $(PROD_FLAGS)

.PHONY: ipa-prod
ipa-prod: ## Build prod IPA for distribution (needs signing set up)
	$(FLUTTER) build ipa --release $(PROD_FLAGS)

##@ Maintenance

.PHONY: clean
clean: ## Remove build output
	$(FLUTTER) clean

.PHONY: reset
reset: clean setup ## Clean, then re-fetch dependencies

.PHONY: ios-flavors
ios-flavors: ## Regenerate the iOS build configs and schemes from flavorizr.yaml
	dart run flutter_flavorizr -f

.PHONY: splash
splash: ## Regenerate native launch screens from flutter_native_splash.yaml
	dart run flutter_native_splash:create
	@printf "\nRe-run this after 'make ios-flavors' — flavorizr rewrites iOS project files.\n\n"

SHELL := /usr/bin/env bash
ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: help init check timeline timeline-csv timeline-raw

help:
	@echo "Targets:"
	@echo "  make init         # copy .env.example -> .env if missing"
	@echo "  make check        # verify required tools + env"
	@echo "  make timeline     # run timeline query (aligned output)"
	@echo "  make timeline-csv # run timeline query (CSV output)"
	@echo "  make timeline-raw # run timeline query (unaligned output)"
	@echo ""
	@echo "Optional vars: CUSTOMER_ID=<uuid> FACILITY_ID=<uuid>"

init:
	@if [[ ! -f .env ]]; then cp .env.example .env; echo "Created .env"; else echo ".env already exists"; fi

check:
	@command -v psql >/dev/null || (echo "psql not found" && exit 1)
	@test -f .env || (echo "Missing .env (run: make init)" && exit 1)
	@echo "OK"

timeline:
	@OUTPUT_FORMAT=aligned scripts/run_timeline.sh "$(CUSTOMER_ID)" "$(FACILITY_ID)"

timeline-csv:
	@OUTPUT_FORMAT=csv scripts/run_timeline.sh "$(CUSTOMER_ID)" "$(FACILITY_ID)"

timeline-raw:
	@OUTPUT_FORMAT=unaligned scripts/run_timeline.sh "$(CUSTOMER_ID)" "$(FACILITY_ID)"

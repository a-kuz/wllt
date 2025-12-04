.PHONY: lint format check

lint:
	swiftlint lint --config .swiftlint.yml

format:
	swiftformat WLLT --config .swiftformat

check: format lint
	@echo "✅ Code formatting and linting complete"


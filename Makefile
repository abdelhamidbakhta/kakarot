.PHONY: build test coverage
cairo_files = $(shell find ./src ./tests -type f -name "*.cairo")

build: check
	$(MAKE) clean
	poetry run python ./scripts/compile_kakarot.py

check:
	poetry lock --check

setup:
	poetry install

test: build-sol deploy
	poetry run pytest tests/integration tests/src --log-cli-level=INFO -n logical
	poetry run pytest tests/end_to_end

test-no-log: build-sol deploy
	poetry run pytest tests/integration tests/src -n logical
	poetry run pytest tests/end_to_end

test-integration: build-sol
	poetry run pytest tests/integration --log-cli-level=INFO -n logical

test-unit:
	poetry run pytest tests/src --log-cli-level=INFO

test-end-to-end: deploy
	poetry run pytest tests/end_to_end --log-cli-level=INFO

run-test-log: build-sol
	poetry run pytest -k $(test) --log-cli-level=INFO -vvv -s

run-test: build-sol
	poetry run pytest -k $(test)

run-test-mark-log: build-sol
	poetry run pytest -m $(mark) --log-cli-level=INFO -vvv -s

run-test-mark: build-sol
	poetry run pytest -m $(mark)

deploy: build
	poetry run python ./scripts/deploy_kakarot.py

format:
	poetry run cairo-format -i ${cairo_files}
	poetry run black tests/. scripts/.
	poetry run isort tests/. scripts/.
	poetry run autoflake . -r

format-check:
	poetry run cairo-format -c ${cairo_files}
	poetry run black tests/. --check
	poetry run isort tests/. --check
	poetry run autoflake . -r -cd

clean:
	rm -rf build
	mkdir build

lint:
	amarna ./src/kakarot -o lint.sarif -rules unused-imports,dead-store,unknown-decorator,unused-arguments

format-mac:
	cairo-format src/**/*.cairo -i
	black tests/.
	isort tests/.

check-resources:
	poetry run python scripts/check_resources.py

get-blockhashes:
	poetry run python scripts/get_latest_blockhashes.py

build-sol:
	forge build --names --force

run:
	mkdir -p deployments/starknet-devnet
	docker run -p 5050:5050 shardlabs/starknet-devnet-rs --seed 0

install-katana:
	cargo install --git https://github.com/dojoengine/dojo katana@0.2.1

run-katana:
	katana --validate-max-steps 16777216 --invoke-max-steps 16777216

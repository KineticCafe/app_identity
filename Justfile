elixir_dir := justfile_directory() / "elixir"
ruby_dir := justfile_directory() / "ruby"
ts_dir := justfile_directory() / "ts"
suite_dir := justfile_directory() / "suite"
tapview := justfile_directory() / "integration" / "tapview"

[private]
default:
  just --list

# Generate and run the integration suite. type=[all, elixir, ruby, typescript]
execute-suite type="all": (generate-suite type) (run-suite type)

# Generates the integration test suite. type=[all, elixir, ruby, typescript]
generate-suite type="all":
  #!/usr/bin/env bash

  set -euo pipefail

  case "{{ type }}" in
  all | elixir | ruby | ts | typescript) : ;;
  *)
    echo >&2 Unknown type {{ type }}.
    exit 1
    ;;
  esac

  mkdir -p "{{ suite_dir }}"
  rm -f "{{ suite_dir }}"/*.json

  case "{{ type }}" in
    all | elixir) just generate-elixir ;;
  esac

  case "{{ type }}" in
    all | ruby) just generate-ruby ;;
  esac

  case "{{ type }}" in
    all | ts | typescript) just generate-ts ;;
  esac

[private]
generate-elixir:
  #!/usr/bin/env bash

  set -euo pipefail

  cd "{{ elixir_dir }}"
  mix app_identity generate "{{ suite_dir }}"

[private]
generate-ruby:
  #!/usr/bin/env bash

  set -euo pipefail

  cd "{{ ruby_dir }}"
  bundle exec ruby -S bin/app-identity-suite-ruby generate "{{ suite_dir }}"

[private]
generate-ts:
  #!/usr/bin/env bash

  set -euo pipefail

  cd "{{ ts_dir }}"
  pnpm --silent cli:generate "{{ suite_dir }}"

# Runs the integration test suite. type=[all, elixir, ruby, typescript]
run-suite type="all":
  #!/usr/bin/env bash

  set -euo pipefail

  case "{{ type }}" in
  all | elixir | ruby | ts | typescript) : ;;
  *)
    echo >&2 Unknown type {{ type }}.
    exit 1
    ;;
  esac

  if ! [[ -d "{{ suite_dir }}" ]]; then
    echo >&2 Suite {{ suite_dir }} does not exist.
  fi

  case "{{ type }}" in
    all | elixir) just run-elixir ;;
  esac

  case "{{ type }}" in
    all | ruby) just run-ruby ;;
  esac

  case "{{ type }}" in
    all | ts | typescript) just run-ts ;;
  esac

[private]
run-elixir:
  #!/usr/bin/env bash

  set -euo pipefail

  cd "{{ elixir_dir }}"
  mix app_identity run "{{ suite_dir }}" | "{{ tapview }}"

[private]
run-ruby:
  #!/usr/bin/env bash

  set -euo pipefail

  cd "{{ ruby_dir }}"
  bundle exec ruby -S bin/app-identity-suite-ruby run "{{ suite_dir }}" |
    "{{ tapview }}"

[private]
run-ts:
  #!/usr/bin/env bash

  set -euo pipefail

  cd "{{ ts_dir }}"
  pnpm --silent cli:run "{{ suite_dir }}" | "{{ tapview }}"

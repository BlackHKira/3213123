#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
CONFIG_SOURCE_DIR="${2:-./src/main/resources/config}"
SERVICES="${SERVICES:-f2c-ecommerce f2c-iam integration-service}"
YQ_BIN="${YQ_BIN:-yq}"

if [ -z "${ENV_NAME}" ]; then
  echo "Usage: $0 <env> [config-source-dir]"
  echo "Example: $0 dev ./src/main/resources/config"
  exit 1
fi

rm -rf ./build/native-config/config
mkdir -p ./build/native-config/config

for svc in ${SERVICES}; do
  echo ">>> Building native config for ${svc}"
  YQ_BIN="${YQ_BIN}" bash ./scripts/build-native-config.sh "${svc}" "${ENV_NAME}" "${CONFIG_SOURCE_DIR}"
done

echo "=== Final generated native config tree ==="
find ./build/native-config/config -maxdepth 3 -type f | sort
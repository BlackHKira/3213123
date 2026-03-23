#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${1:-}"
ENV_NAME="${2:-}"
CONFIG_SOURCE_DIR="${3:-./src/main/resources/config}"
YQ_BIN="${YQ_BIN:-yq}"

if [ -z "${SERVICE_NAME}" ] || [ -z "${ENV_NAME}" ]; then
  echo "Usage: $0 <service-name> <env> [config-source-dir]"
  echo "Example: $0 f2c-ecommerce dev ./src/main/resources/config"
  exit 1
fi

if [ ! -d "${CONFIG_SOURCE_DIR}" ]; then
  echo "ERROR: Config source directory not found: ${CONFIG_SOURCE_DIR}"
  exit 1
fi

if [ ! -d "${CONFIG_SOURCE_DIR}/${SERVICE_NAME}" ]; then
  echo "ERROR: Service directory not found: ${CONFIG_SOURCE_DIR}/${SERVICE_NAME}"
  exit 1
fi

if ! command -v "${YQ_BIN}" >/dev/null 2>&1 && [ ! -x "${YQ_BIN}" ]; then
  echo "ERROR: yq not found: ${YQ_BIN}"
  exit 1
fi

BUILD_ROOT="./build/native-config"
DIST_DIR="${BUILD_ROOT}/config/${SERVICE_NAME}"
TMP_DIR="${BUILD_ROOT}/tmp/${SERVICE_NAME}"

BASE_TMP="${TMP_DIR}/base.yml"
FINAL_TMP="${TMP_DIR}/final.yml"

rm -rf "${DIST_DIR}" "${TMP_DIR}"
mkdir -p "${DIST_DIR}" "${TMP_DIR}"

printf '{}\n' > "${BASE_TMP}"
printf '{}\n' > "${FINAL_TMP}"

merge_file() {
  local src="$1"
  local target="$2"

  if [ -f "${src}" ]; then
    echo "Merging ${src} -> ${target}"
    "${YQ_BIN}" eval-all '. as $item ireduce ({}; . * $item)' "${target}" "${src}" > "${target}.merged"
    mv "${target}.merged" "${target}"
  else
    echo "Skip missing file: ${src}"
  fi
}

merge_glob_sorted() {
  local pattern="$1"
  local target="$2"
  local matched=0

  for f in ${pattern}; do
    if [ -f "${f}" ]; then
      matched=1
      merge_file "${f}" "${target}"
    fi
  done

  if [ "${matched}" -eq 0 ]; then
    echo "Skip missing pattern: ${pattern}"
  fi
}

echo "=== Build native config for service=${SERVICE_NAME}, env=${ENV_NAME} ==="
echo "CONFIG_SOURCE_DIR=${CONFIG_SOURCE_DIR}"

# Base layer
merge_file "${CONFIG_SOURCE_DIR}/common/application.yml" "${BASE_TMP}"
merge_glob_sorted "${CONFIG_SOURCE_DIR}/shared/*.yml" "${BASE_TMP}"
merge_file "${CONFIG_SOURCE_DIR}/${SERVICE_NAME}/application.yml" "${BASE_TMP}"

# Final application.yml
cp "${BASE_TMP}" "${DIST_DIR}/application.yml"

# Env layer
cp "${BASE_TMP}" "${FINAL_TMP}"
merge_file "${CONFIG_SOURCE_DIR}/common/application-${ENV_NAME}.yml" "${FINAL_TMP}"
merge_file "${CONFIG_SOURCE_DIR}/${SERVICE_NAME}/application-${ENV_NAME}.yml" "${FINAL_TMP}"

cp "${FINAL_TMP}" "${DIST_DIR}/application-${ENV_NAME}.yml"

echo "=== Generated files for ${SERVICE_NAME} ==="
ls -l "${DIST_DIR}"
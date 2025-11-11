#!/usr/bin/env bash
set -euo pipefail

. /hive/miners/custom/neptune_miner/h-manifest.conf

cd /hive/miners/custom/neptune_miner || exit 1
rm -f neptune_miner.log

set +u
[ -f /hive-config/wallet.conf ] && . /hive-config/wallet.conf
[ -f /hive-config/rig.conf ]    && . /hive-config/rig.conf
set -u

if [ -f /hive-config/wallet.conf ]; then
  WALLET="$(echo "${CUSTOM_USER_CONFIG:-}" | sed -n 's/.*wallet=\([^[:space:]]*\).*/\1/p')"
else
  WALLET=""
fi

WORKER_NAME="${CUSTOM_TEMPLATE#*.}"

CUSTOM_GPUS="$(echo "${CUSTOM_USER_CONFIG:-}" | sed -n 's/.*gpus=\([^[:space:]]*\).*/\1/p')"

if [ -z "${CUSTOM_URL:-}" ]; then
  echo "Missing CUSTOM_URL (pool address)"
  exit 1
fi

if [ -z "${WALLET:-}" ]; then
  echo "Missing WALLET (wallet address)"
  exit 1
fi

GPU_ARGS=()
if [ -n "${CUSTOM_GPUS:-}" ]; then
  GPU_ARGS+=(--gpus "${CUSTOM_GPUS}")
fi

./neptune_miner \
  --pool "${CUSTOM_URL}" \
  --worker "${WORKER_NAME}" \
  --wallet "${WALLET}" \
  --api 127.0.0.1:${MINER_API_PORT} \
  "${GPU_ARGS[@]}" \
  2>&1 | tee neptune_miner.log &

wait




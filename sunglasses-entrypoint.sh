#!/bin/sh

export SUNGLASSES_DB=${SUNGLASSES_DB:-/sunlight/sunglasses.db}
export SUNGLASSES_LISTEN_ADDRESS=${SUNGLASSES_LISTEN_ADDRESS:-0.0.0.0}
export SUNGLASSES_LISTEN_PORT=${SUNGLASSES_LISTEN_PORT:-80}

# if you don't provide a log ID, we have to extract the log ID from the monitoring prefix URL.
export SUNLIGHT_LOG_ID=${SUNLIGHT_LOG_ID:-`curl --silent --fail http://caddy/log.v3.json | jq --raw-output '.log_id'`}

sunglasses \
  -db "${SUNGLASSES_DB}" \
  -id "${SUNLIGHT_LOG_ID}" \
  -listen "tcp:${SUNGLASSES_LISTEN_ADDRESS}:${SUNGLASSES_LISTEN_PORT}" \
  -monitoring "http://caddy" \
  -submission "http://sunlight"

# EOF

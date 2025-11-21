#!/bin/sh

SUNGLASSES_DB=${SUNGLASSES_DB:-/sunlight/sunglasses.db}
SUNGLASSES_LISTEN_ADDRESS=${SUNGLASSES_LISTEN_ADDRESS:-0.0.0.0}
SUNGLASSES_LISTEN_PORT=${SUNGLASSES_LISTEN_PORT:-80}
# Uncomment above and remove below if you're using skylight instead of caddy.
#export SUNLIGHT_INTERNAL_MONITORING_PREFIX=${SUNLIGHT_INTERNAL_MONITORING_PREFIX:-http://skylight}
SUNLIGHT_INTERNAL_MONITORING_PREFIX=${SUNLIGHT_INTERNAL_MONITORING_PREFIX:-http://caddy}
# assumes you're using the default config without https, adjust as required.
SUNLIGHT_INTERNAL_SUBMISSION_PREFIX=${SUNLIGHT_INTERNAL_SUBMISSION_PREFIX:-http://sunlight}

# NOTE: Sunglasses currently gets stuck if it tries to index a CT log that doesn't yet have any CT certificates logged to it. It will not restart or re-poll the log it just... doesn't do anything. 
#       But once it sees that one or more certificates have been logged it will start indexing the log periodically. So we just exit and hope that by the time the container restarts something will have been logged to it.
CHECKPOINT_INDEX=$(curl --silent --fail ${SUNLIGHT_INTERNAL_MONITORING_PREFIX}/checkpoint | grep -E '^[0-9]+$')
if [ "${CHECKPOINT_INDEX}x" = "x" ] || [ ${CHECKPOINT_INDEX} -eq 0 ]; then
  echo "### No checkpoint index found or checkpoint index is 0, sunglasses will not be able to index the log, sleeping for 30 seconds and restarting then."
  sleep 30
  exit 1
fi

# if you don't provide a log ID, we have to extract the log ID from the monitoring prefix URL.
SUNLIGHT_LOG_ID=${SUNLIGHT_LOG_ID:-`curl --silent --fail ${SUNLIGHT_INTERNAL_MONITORING_PREFIX}/log.v3.json | jq --raw-output '.log_id'`}
if [ -z "${SUNLIGHT_LOG_ID}" ]; then
  echo "### No log ID available. Sunglasses cannot be worn."
  sleep 30
  exit 1
fi

sunglasses \
  -db "${SUNGLASSES_DB}" \
  -id "${SUNLIGHT_LOG_ID}" \
  -listen "tcp:${SUNGLASSES_LISTEN_ADDRESS}:${SUNGLASSES_LISTEN_PORT}" \
  -monitoring "${SUNLIGHT_INTERNAL_MONITORING_PREFIX}" \
  -submission "${SUNLIGHT_INTERNAL_SUBMISSION_PREFIX}"

# EOF

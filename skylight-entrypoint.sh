#!/bin/sh

export SKYLIGHT_LISTEN_ADDRESS=${SKYLIGHT_LISTEN_ADDRESS:-0.0.0.0}
export SKYLIGHT_LISTEN_PORT=${SKYLIGHT_LISTEN_PORT:-80}
export SKYLIGHT_TESTCERT=${SKYLIGHT_TESTCERT:-false}

export SUNLIGHT_LOG_NAME=${SUNLIGHT_LOG_NAME:-testlog}
export SKYLIGHT_INTERNAL_URL=${SKYLIGHT_INTERNAL_URL:-http://skylight}

mkdir -p /skylight
test -f /skylight/skylight.yaml || echo "listen:
  - ${SKYLIGHT_LISTEN_ADDRESS}:${SKYLIGHT_LISTEN_PORT}
logs:
  - shortname: ${SUNLIGHT_LOG_NAME}
    monitoringprefix: ${SKYLIGHT_INTERNAL_URL}
    localdirectory: /tank/logs/${SUNLIGHT_LOG_NAME}/data
    staging: false
" > /skylight/skylight.yaml

cat /skylight/skylight.yaml

cd /skylight

if [ "${SKYLIGHT_TESTCERT}x" = "truex" ]; then
  echo "### Using test certificate..."
  SKYLIGHT_EXTRA_ARGS="${SKYLIGHT_EXTRA_ARGS} -testcert"

  if [ ! -f /skylight/skylight.pem ]; then
    echo "### No skylight.pem found, generating self signed certificate..."
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
      -subj "/C=AU/ST=Queensland/L=Brisbane/O=Good Roots Work/OU=Eng/CN=skylight" \
      -out skylight.pem \
      -keyout skylight-key.pem
  fi
fi

test -f "/tank/logs/${SUNLIGHT_LOG_NAME}/data/status" || echo "OK" > "/tank/logs/${SUNLIGHT_LOG_NAME}/data/status"

skylight -c /skylight/skylight.yaml ${SKYLIGHT_EXTRA_ARGS:-}

# EOF

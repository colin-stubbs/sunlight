#!/bin/sh

# The current date/time in simple UTC zoned RFC3339 format, used in our generated monitor.json files if we're auto-generating them.
NOW=`date -u -Iseconds | sed -r 's/\+00:00/Z/'`

export LOAD_TEST_DATA=${LOAD_TEST_DATA:-false}
export GEN_TEST_CERTS=${GEN_TEST_CERTS:-}
export LOAD_GENERATED_CERTS=${LOAD_GENERATED_CERTS:-}
export CERT_CHAINS_NDJSON=${CERT_CHAINS_NDJSON:-compact.chains.ndjson}

export SUNLIGHT_LISTEN_ADDRESS=${SUNLIGHT_LISTEN_ADDRESS:-0.0.0.0}
export SUNLIGHT_LISTEN_PORT=${SUNLIGHT_LISTEN_PORT:-80}
export SUNLIGHT_LOG_NAME=${SUNLIGHT_LOG_NAME:-testlog}
export SUNLIGHT_INCEPTION=${SUNLIGHT_INCEPTION:-`date -I`}
export SUNLIGHT_NOT_AFTER_START=${SUNLIGHT_NOT_AFTER_START:-2025-07-01T00:00:00Z}
export SUNLIGHT_NOT_AFTER_LIMIT=${SUNLIGHT_NOT_AFTER_LIMIT:-2035-01-01T00:00:00Z}
export SUNLIGHT_SUBMISSION_PREFIX=${SUNLIGHT_SUBMISSION_PREFIX:-https://localhost}
export SUNLIGHT_MONITORING_PREFIX=${SUNLIGHT_MONITORING_PREFIX:-http://localhost}
export SUNLIGHT_PERIOD=${SUNLIGHT_PERIOD:-200}
export SUNLIGHT_POOL_SIZE=${SUNLIGHT_POOL_SIZE:-1}
export SUNLIGHT_EXTRA_ROOTS_PEM=${SUNLIGHT_EXTRA_ROOTS_PEM:-/sunlight/extra_roots.pem}
export SUNLIGHT_EXTRA_ARGS=${SUNLIGHT_EXTRA_ARGS:-}
export SUNLIGHT_TESTCERT=${SUNLIGHT_TESTCERT:-false}

# add Sunglasses RFC6962 to sunlight static CT tiles proxy if desired
export VERY_BRIGHT_WANT_SUNGLASSES=${VERY_BRIGHT_WANT_SUNGLASSES:-false}

mkdir -p /sunlight
mkdir -p /tank/shared
mkdir -p /tank/enc
mkdir -p /tank/logs/${SUNLIGHT_LOG_NAME}/data

test -f /sunlight/sunlight.yaml || echo "listen:
  - "${SUNLIGHT_LISTEN_ADDRESS}:${SUNLIGHT_LISTEN_PORT}"
checkpoints: /tank/shared/checkpoints.db
logs:
  - shortname: ${SUNLIGHT_LOG_NAME}
    roots: ${SUNLIGHT_EXTRA_ROOTS_PEM}
    inception: ${SUNLIGHT_INCEPTION}
    period: ${SUNLIGHT_PERIOD}
    submissionprefix: ${SUNLIGHT_SUBMISSION_PREFIX}
    monitoringprefix: ${SUNLIGHT_MONITORING_PREFIX}
    secret: /tank/enc/${SUNLIGHT_LOG_NAME}.seed.bin
    cache: /tank/logs/${SUNLIGHT_LOG_NAME}/cache.db
    poolsize: ${SUNLIGHT_POOL_SIZE}
    localdirectory: /tank/logs/${SUNLIGHT_LOG_NAME}/data
    notafterstart: ${SUNLIGHT_NOT_AFTER_START}
    notafterlimit: ${SUNLIGHT_NOT_AFTER_LIMIT}
" > /sunlight/sunlight.yaml

test -f /tank/shared/checkpoints.db || sqlite3 /tank/shared/checkpoints.db "CREATE TABLE checkpoints (logID BLOB PRIMARY KEY, body TEXT)"
test -f /tank/enc/${SUNLIGHT_LOG_NAME}.seed.bin || sunlight-keygen -f /tank/enc/${SUNLIGHT_LOG_NAME}.seed.bin
test -f /tank/logs/${SUNLIGHT_LOG_NAME}/data/status || echo "OK" > /tank/logs/${SUNLIGHT_LOG_NAME}/data/status

# add test ca certs to trusted roots if requested and the files exist
if [ ${LOAD_TEST_DATA} = "true" ]; then
  cd /sunlight/testdata
  # run generate.sh script to create extra test certs if it exists and is executable.
  # we need to do this here and now to ensure we can insert test-ca.pem before sunlight starts.
  # NOTE: we override GEN_TEST_CERTS to 1 to ensure we only generate a single cert/chain instead of, potentially, a very large number that will take a long time which should happen *AFTER* sunlight starts.
  test -x /sunlight/testdata/generate.sh && GEN_TEST_CERTS=1 /sunlight/testdata/generate.sh

  echo "### Adding test CA certificates to trusted roots..."
  for i in `find . -type f -name fake-ca\*.cert -o -type f -name test-ca.pem` ; do
    test -f "${i}" && cat "${i}" >> ${SUNLIGHT_EXTRA_ROOTS_PEM}
  done
fi

cd /sunlight

if [ "${SUNLIGHT_TESTCERT}x" = "truex" ]; then
  echo "### Using test certificate..."
  SUNLIGHT_EXTRA_ARGS="${SUNLIGHT_EXTRA_ARGS} -testcert"

  if [ ! -f /sunlight/sunlight.pem ]; then
    echo "### No sunlight.pem found, generating self signed certificate..."
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
      -subj "/C=AU/ST=Queensland/L=Brisbane/O=Good Roots Work/OU=Eng/CN=sunlight" \
      -out sunlight.pem \
      -keyout sunlight-key.pem
  fi
fi

# run post start script - this runs in the background and *should* perform a loop waiting until sunlight has started before doing *things*.
nohup /sunlight/post_start.sh 1>/var/log/sunlight_post_start_stdout.log 2>/var/log/sunlight_post_start_stderr.log &

sunlight -c /sunlight/sunlight.yaml ${SUNLIGHT_EXTRA_ARGS:-}

# EOF

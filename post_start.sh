#!/bin/sh

echo -n "### Waiting for sunlight to start and respond to HTTP requests..."
while ! curl -s http://127.0.0.1:${SUNLIGHT_LISTEN_PORT}/ >/dev/null 2>&1; do
  sleep 1
  echo -n "."
done
echo "OK!"

# The current date/time in simple UTC zoned RFC3339 format, used in our generated monitor.json files if we're auto-generating them.
NOW=`date -u -Iseconds | sed -r 's/\+00:00/Z/'`

# Used in our generated monitor.json files if we're auto-generating them, e.g. a long time ago in a galaxy far, far away...
NOT_AFTER_START=`cat /tank/logs/${SUNLIGHT_LOG_NAME}/data/log.v3.json | jq --raw-output '.temporal_interval.start_inclusive'`
# Used in our generated monitor.json files if we're auto-generating them, e.g. now + years in simple UTC zoned RFC3339 format.
NOT_AFTER_LIMIT=`cat /tank/logs/${SUNLIGHT_LOG_NAME}/data/log.v3.json | jq --raw-output '.temporal_interval.start_inclusive'`

SUNLIGHT_LOG_ID=`cat /tank/logs/${SUNLIGHT_LOG_NAME}/data/log.v3.json | jq --raw-output '.log_id'`
SUNLIGHT_LOG_PUBLIC_KEY=`cat /tank/logs/${SUNLIGHT_LOG_NAME}/data/log.v3.json | jq --raw-output '.key'`

# generate monitor.json files, refer to:
#  1. https://googlechrome.github.io/CertificateTransparency/log_lists.html
#  2. https://www.gstatic.com/ct/log_list/v3/log_list_schema.json

MONITOR_RFC_JSON='{
  "is_all_logs": false,
  "version": "1.0.0",
  "log_list_timestamp": "'${NOW}'",
  "name": "testing",
  "operators": [
    {
      "name": "testing",
      "email": [
        "test@example.com"
      ],
      "logs": [
        {
          "description": "'${SUNLIGHT_LOG_NAME}'",
          "log_id": "'${SUNLIGHT_LOG_ID}'",
          "key": "'${SUNLIGHT_LOG_PUBLIC_KEY}'",
          "url": "'${SUNLIGHT_MONITORING_PREFIX}'",
          "mmd": 86400,
          "state": {
            "usable": {
              "timestamp": "'${NOW}'"
            }
          },
          "temporal_interval": {
            "start_inclusive": "'${NOT_AFTER_START}'",
            "end_exclusive": "'${NOT_AFTER_LIMIT}'"
          }
        }
      ],
      "tiled_logs": []
    }
  ]
}'

MONITOR_STATIC_JSON='{
  "is_all_logs": false,
  "version": "1.0.0",
  "log_list_timestamp": "'${NOW}'",
  "name": "testing",
  "operators": [
    {
      "name": "testing",
      "email": [
        "test@example.com"
      ],
      "logs": [],
      "tiled_logs": [
        {
          "description": "'${SUNLIGHT_LOG_NAME}'",
          "log_id": "'${SUNLIGHT_LOG_ID}'",
          "key": "'${SUNLIGHT_LOG_PUBLIC_KEY}'",
          "monitoring_url": "'${SUNLIGHT_MONITORING_PREFIX}'",
          "submission_url": "'${SUNLIGHT_SUBMISSION_PREFIX}'",
          "mmd": 60,
          "state": {
            "usable": {
              "timestamp": "'${NOW}'"
            }
          },
          "temporal_interval": {
            "start_inclusive": "'${NOT_AFTER_START}'",
            "end_exclusive": "'${NOT_AFTER_LIMIT}'"
          }
        }
      ]
    }
  ]
}'

MONITOR_COMBINED_JSON='{
  "is_all_logs": false,
  "version": "1.0.0",
  "log_list_timestamp": "'${NOW}'",
  "name": "testing",
  "operators": [
    {
      "name": "testing",
      "email": [
        "test@example.com"
      ],
      "logs": [
        {
          "description": "'${SUNLIGHT_LOG_NAME}'",
          "log_id": "'${SUNLIGHT_LOG_ID}'",
          "key": "'${SUNLIGHT_LOG_PUBLIC_KEY}'",
          "url": "'${SUNLIGHT_MONITORING_PREFIX}'",
          "mmd": 86400,
          "state": {
            "usable": {
              "timestamp": "'${NOW}'"
            }
          },
          "temporal_interval": {
            "start_inclusive": "'${NOT_AFTER_START}'",
            "end_exclusive": "'${NOT_AFTER_LIMIT}'"
          }
        }
      ],
      "tiled_logs": [
        {
          "description": "'${COMPACTLOG_LOG_NAME}'",
          "log_id": "'${SUNLIGHT_LOG_ID}'",
          "key": "'${SUNLIGHT_LOG_PUBLIC_KEY}'",
          "monitoring_url": "'${SUNLIGHT_MONITORING_PREFIX}'",
          "submission_url": "'${SUNLIGHT_SUBMISSION_PREFIX}'",
          "mmd": 60,
          "state": {
            "usable": {
              "timestamp": "'${NOW}'"
            }
          },
          "temporal_interval": {
            "start_inclusive": "'${NOT_AFTER_START}'",
            "end_exclusive": "'${NOT_AFTER_LIMIT}'"
          }
        }
      ]
    }
  ]
}'

test -f /tank/logs/${SUNLIGHT_LOG_NAME}/data/monitor-rfc6962.json || echo "${MONITOR_RFC_JSON}" > /tank/logs/${SUNLIGHT_LOG_NAME}/data/monitor-rfc6962.json
test -f /tank/logs/${SUNLIGHT_LOG_NAME}/data/monitor-static.json || echo "${MONITOR_STATIC_JSON}" > /tank/logs/${SUNLIGHT_LOG_NAME}/data/monitor-static.json
test -f /tank/logs/${SUNLIGHT_LOG_NAME}/data/monitor-combined.json || echo "${MONITOR_COMBINED_JSON}" > /tank/logs/${SUNLIGHT_LOG_NAME}/data/monitor-combined.json

#if [ "${VERY_BRIGHT_WANT_SUNGLASSES}x" == "truex" ]; then
#  nohup sunglasses -db /sunlight/sunglasses.db -id "${SUNLIGHT_LOG_ID}" -listen tcp:80 -monitoring http://caddy/ -submission https://localhost/ 1>/var/log/sunglasses_stdout.log 2>/var/log/sunglasses_stderr.log &
#fi

cd /sunlight/testdata
export CTLOG_NAME=${SUNLIGHT_LOG_NAME:-testlog}
export CTLOG_SUBMISSION_BASE_URL=http://localhost/ct/v1
test -f /sunlight/testdata/insert.sh && /sunlight/testdata/insert.sh

# EOF

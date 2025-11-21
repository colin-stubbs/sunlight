FROM golang:trixie

# create these individually as layers so that they can be cached and re-used if they have not changed.
RUN go install filippo.io/sunlight/cmd/...@latest
RUN go install src.agwa.name/sunglasses@latest

RUN mkdir -p /sunlight && \
    mkdir -p /tank/shared

COPY sunlight-entrypoint.sh /usr/local/bin/sunlight-entrypoint.sh
COPY skylight-entrypoint.sh /usr/local/bin/skylight-entrypoint.sh
COPY sunglasses-entrypoint.sh /usr/local/bin/sunglasses-entrypoint.sh
COPY post_start.sh /sunlight/post_start.sh

RUN apt update && \
    apt install -y curl jq sqlite3 && \
    apt clean all && \
    rm -rf /var/lib/apt/lists/* && \
    sqlite3 /tank/shared/checkpoints.db "CREATE TABLE checkpoints (logID BLOB PRIMARY KEY, body TEXT)"

WORKDIR /sunlight

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=30s CMD curl --silent --fail https://127.0.0.1:${SUNLIGHT_LISTEN_PORT:-443}/health || exit 1

ENTRYPOINT ["/usr/local/bin/sunlight-entrypoint.sh"]

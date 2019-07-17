#!/bin/bash

sleep 5

CASSANDRA_SEEDS=$(host "$CASSANDRA_SEED_DISCOVERY" | \
    grep -v "$(hostname -i)" | \
    sort | \
    head -2 | \
    awk '{print $4}' | \
xargs)

if [ -n "$CASSANDRA_SEEDS" ]; then
    CASSANDRA_SEEDS=${CASSANDRA_SEEDS// /,}
    export CASSANDRA_SEEDS
fi

/docker-entrypoint.sh "$@"

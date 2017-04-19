#!/bin/bash

sleep 5

CASSANDRA_SEEDS=$(host $CASSANDRA_SEED_DISCOVERY | \
    grep -v $(hostname -i) | \
    sort | \
    head -2 | \
    awk '{print $4}' | \
xargs | sed -e 's# #,#g')

if [ ! -z "$CASSANDRA_SEEDS" ]; then
    export CASSANDRA_SEEDS
fi

/docker-entrypoint.sh "$@"

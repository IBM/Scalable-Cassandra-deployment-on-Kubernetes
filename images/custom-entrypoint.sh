CASSANDRA_SEEDS=$(host $CASSANDRA_SEED_DISCOVERY | \
    sort | \
    awk '{print $4}' | \
    xargs)

if [ ! -z "$CASSANDRA_SEEDS" ]; then
    export CASSANDRA_SEEDS
fi

/docker-entrypoint.sh "$@"

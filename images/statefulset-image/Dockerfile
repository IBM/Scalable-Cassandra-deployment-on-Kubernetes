FROM cassandra:3.0

COPY initial-seed.cql /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["cassandra", "-f", "-D", "cassandra.consistent.rangemovement=false"]

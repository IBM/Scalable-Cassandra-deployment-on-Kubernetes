FROM cassandra:latest
MAINTAINER Ishan Gulhane <ishan.gulhane@ibm.com>
ENV REFRESHED_AT 2017-03-15
COPY initial-seed.cql /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["cassandra", "-f"]
FROM ubuntu:xenial

MAINTAINER Chris Rust <chris.rust@solarwinds.com>

# Base configuration
USER root
ENV DEBIAN_FRONTEND noninteractive

RUN \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get -y install apt-transport-https

# TODO: THIS COMMENTED SECTION ISNT WORKING, SO USING --allow-unauthenticated BELOW FOR NOW
#RUN \
#  apt-get -y install debian-archive-keyring curl && \
#  curl -sS -o /tmp/packagecloud.key https://packagecloud.io/gpg.key && \
#  apt-key add /tmp/packagecloud.key
# another option for grabbing key is this, but it isn't working either:
#  apt-key adv --keyserver packagecloud.io --recv-keys 7BD5A64799D0A3FB

# Install AppOptics Host Agent from their Ubuntu repo
COPY ./conf/appoptics-xenial-repo.list /etc/apt/sources.list.d/appoptics-snap.list

RUN \
  apt-get update && \
  apt-get -y --allow-unauthenticated install appoptics-snaptel && \
  rm -rf /var/lib/apt/lists/* /tmp/*

# The dir-structure and perms commands below were pulled from the systemd service file bundled with the dpkg
RUN \
  mkdir -p /tmp/appoptics-snaptel && \
  chown -R appoptics:appoptics /tmp/appoptics-snaptel && \
  chmod 775 -R /tmp/appoptics-snaptel && \
  mkdir -p /var/log/appoptics && \
  chown -R appoptics:appoptics /var/log/appoptics && \
  chmod 775 -R /var/log/appoptics && \
  mkdir -p /var/run/appoptics && \
  chown -R appoptics:appoptics /var/run/appoptics && \
  chmod 775 -R /var/run/appoptics

COPY ./conf/appoptics-config.yaml /opt/appoptics/etc/config.yaml

USER appoptics
WORKDIR /opt/appoptics

# Run AppOptics Host Agent
CMD ["/opt/appoptics/sbin/snapteld", "--config", "/opt/appoptics/etc/config.yaml"]

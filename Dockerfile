FROM ubuntu:xenial

MAINTAINER Chris Rust <chris.rust@solarwinds.com>

# Base configuration
USER root
ENV DEBIAN_FRONTEND noninteractive

RUN \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get -y install apt-transport-https ca-certificates curl

# Install AppOptics Host Agent from their Ubuntu repo
COPY ./conf/appoptics-xenial-repo.list /etc/apt/sources.list.d/appoptics-snap.list

RUN \
  curl -L https://packagecloud.io/AppOptics/appoptics-snap/gpgkey | apt-key add - && \
  apt-get update && \
  apt-get -y install appoptics-snaptel && \
  apt-get -y purge curl && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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

# Disable Host Agent System Metrics (no need to waste resources on gathering system metrics for the AppOptics pod)
RUN \
  rm /opt/appoptics/autoload/snap-plugin-collector-aosystem && \
  rm /opt/appoptics/autoload/task-aosystem-warmup.yaml && \
  rm /opt/appoptics/autoload/task-aosystem.yaml

COPY ./conf/appoptics-config.yaml /opt/appoptics/etc/config.yaml
COPY ./conf/appoptics-config-kubernetes.yaml /opt/appoptics/etc/plugins.d/kubernetes.yaml

USER appoptics
WORKDIR /opt/appoptics

# Run AppOptics Host Agent
CMD ["/opt/appoptics/sbin/snapteld", "--config", "/opt/appoptics/etc/config.yaml"]

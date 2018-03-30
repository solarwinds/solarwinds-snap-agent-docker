FROM ubuntu:xenial

MAINTAINER Chris Rust <chris.rust@solarwinds.com>

ENV APPOPTICS_SNAPTEL_VERSION='2.0.0-ao1.1475'

USER root
ENV DEBIAN_FRONTEND noninteractive

RUN \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get -y install apt-transport-https ca-certificates curl

# Configure AppOptics Host Agent Ubuntu repo
COPY ./conf/appoptics-xenial-repo.list /etc/apt/sources.list.d/appoptics-snap.list

RUN \
  curl -L https://packagecloud.io/AppOptics/appoptics-snap/gpgkey | apt-key add - && \
  apt-get update && \
  apt-get -y install appoptics-snaptel=${APPOPTICS_SNAPTEL_VERSION} && \
  apt-get -y purge curl && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN \
  mkdir -p /tmp/appoptics-snaptel && \
  mkdir -p /var/log/appoptics && \
  mkdir -p /var/run/appoptics && \
  mkdir -p /tmp/appoptics-configs

COPY ./conf/appoptics-config.yaml /opt/appoptics/etc/config.yaml
COPY ./conf/appoptics-config-kubernetes.yaml /tmp/appoptics-configs/kubernetes.yaml
COPY ./conf/appoptics-config-docker.yaml /tmp/appoptics-configs/docker.yaml
COPY ./conf/appoptics-init.sh /opt/appoptics/etc/init.sh

WORKDIR /opt/appoptics

# Run AppOptics Host Agent
CMD ["/opt/appoptics/etc/init.sh"]

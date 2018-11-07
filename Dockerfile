FROM ubuntu:xenial

LABEL maintainer='Chris Rust <chris.rust@solarwinds.com>'

ENV APPOPTICS_SNAPTEL_VERSION '2.0.0-ao1.1919'

USER root
ENV DEBIAN_FRONTEND noninteractive

RUN \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    jq \
    python

# Configure AppOptics Host Agent Ubuntu repo
COPY ./conf/appoptics-xenial-repo.list /etc/apt/sources.list.d/appoptics-snap.list

RUN \
  curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
  python get-pip.py && \
  pip install setuptools wheel && \
  pip install yq && \
  pip uninstall pip -y && \
  curl -L https://packagecloud.io/AppOptics/appoptics-snap/gpgkey | apt-key add - && \
  apt-get update && \
  apt-get -y install appoptics-snaptel=${APPOPTICS_SNAPTEL_VERSION} && \
  apt-get -y purge curl python && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
  mkdir -p /tmp/appoptics-snaptel \
           /var/log/appoptics \
           /var/run/appoptics \
           /tmp/appoptics-configs

COPY ./conf/appoptics-config.yaml /opt/appoptics/etc/config.yaml
COPY ./conf/appoptics-init.sh /opt/appoptics/etc/init.sh

WORKDIR /opt/appoptics

# Run AppOptics Host Agent
CMD ["/opt/appoptics/etc/init.sh"]

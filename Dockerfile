FROM ubuntu:xenial

LABEL authors='Chris Rust <chris.rust@solarwinds.com>, Dawid Śmiech <dawid.smiech@solarwinds.com>'

USER root
ENV DEBIAN_FRONTEND noninteractive

RUN \
  apt-get update && \
  apt-get -y install software-properties-common && \
  LC_ALL=C.UTF-8 add-apt-repository -y ppa:rmescandon/yq && \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    yq

ARG swisnap_repo=swisnap

RUN \
  echo "deb https://packagecloud.io/solarwinds/${swisnap_repo}/ubuntu/ xenial main" > /etc/apt/sources.list.d/swisnap.list && \
  curl -L https://packagecloud.io/solarwinds/${swisnap_repo}/gpgkey | apt-key add - && \
  apt-get update && \
  apt-get -y install solarwinds-snap-agent && \
  usermod -aG root solarwinds && \
  apt-get -y purge curl && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
  mkdir -p /tmp/SolarWinds/Snap \
           /var/log/SolarWinds/Snap \
           /var/run/SolarWinds/Snap

COPY ./conf/swisnap-config.yaml /opt/SolarWinds/Snap/etc/config.yaml
COPY ./conf/swisnap-init.sh /opt/SolarWinds/Snap/etc/init.sh

WORKDIR /opt/SolarWinds/Snap

# Run SolarWinds Snap Agent
CMD ["/opt/SolarWinds/Snap/etc/init.sh"]

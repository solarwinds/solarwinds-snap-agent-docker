FROM ubuntu:xenial

LABEL authors='Chris Rust <chris.rust@solarwinds.com>, Dawid Śmiech <dawid.smiech@solarwinds.com>'

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

ARG swisnap_repo=swisnap

RUN \
  curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
  python get-pip.py && \
  pip install setuptools wheel && \
  pip install yq && \
  pip uninstall pip -y && \
  echo "deb https://packagecloud.io/solarwinds/${swisnap_repo}/ubuntu/ xenial main" > /etc/apt/sources.list.d/swisnap.list && \
  curl -L https://packagecloud.io/solarwinds/${swisnap_repo}/gpgkey | apt-key add - && \
  apt-get update && \
  apt-get -y install solarwinds-snap-agent && \
  usermod -aG root solarwinds && \
  apt-get -y purge curl python && \
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

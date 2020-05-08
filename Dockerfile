FROM ubuntu:eoan

LABEL authors='Dawid Śmiech <dawid.smiech@solarwinds.com>'

ENV DEBIAN_FRONTEND noninteractive
ENV LC_ALL=C.UTF-8

ARG swisnap_repo=swisnap
RUN apt-get update && apt-get install -y \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    docker.io \
    curl \
    gnupg \
  && add-apt-repository -y ppa:rmescandon/yq \
  && echo "deb https://packagecloud.io/solarwinds/${swisnap_repo}/ubuntu/ eoan main" > /etc/apt/sources.list.d/swisnap.list \
  && curl -L https://packagecloud.io/solarwinds/${swisnap_repo}/gpgkey | apt-key add - \
  && apt-get update \
  && apt-get install -y yq

ARG swisnap_version=2.7.5.577
RUN apt-get update \
  && apt-get -y install solarwinds-snap-agent=${swisnap_version} \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /tmp/SolarWinds/Snap /var/log/SolarWinds/Snap /var/run/SolarWinds/Snap

WORKDIR /opt/SolarWinds/Snap
COPY ./conf/swisnap-init.sh /opt/SolarWinds/Snap/etc/init.sh

EXPOSE 21413
# Run SolarWinds Snap Agent
CMD ["/opt/SolarWinds/Snap/etc/init.sh"]
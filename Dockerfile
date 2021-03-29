FROM ubuntu:bionic

LABEL authors='SolarWinds AppOptics team <technicalsupport@solarwinds.com>'

USER root
ARG DEBIAN_FRONTEND=noninteractive
ARG swisnap_repo=swisnap

RUN apt-get update && \
    apt-get -y install software-properties-common && \
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:rmescandon/yq && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install \
      apt-transport-https \
      ca-certificates \
      docker.io \
      curl \
      yq && \ 
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG swisnap_version
RUN echo "deb https://packagecloud.io/solarwinds/${swisnap_repo}/ubuntu/ bionic main" > /etc/apt/sources.list.d/swisnap.list && \
  curl -L https://packagecloud.io/solarwinds/${swisnap_repo}/gpgkey | apt-key add - && \
  apt-get update && \
  apt-get -y install solarwinds-snap-agent=${swisnap_version} && \
  usermod -aG root solarwinds && \
  apt-get -y purge curl && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
  mkdir -p /tmp/SolarWinds/Snap \
           /var/log/SolarWinds/Snap \
           /var/run/SolarWinds/Snap

COPY ./conf/swisnap-init.sh /opt/SolarWinds/Snap/etc/init.sh
WORKDIR /opt/SolarWinds/Snap

EXPOSE 21413
# Run SolarWinds Snap Agent
CMD ["/opt/SolarWinds/Snap/etc/init.sh"]

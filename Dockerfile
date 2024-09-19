FROM ubuntu:focal

LABEL authors='SolarWinds AppOptics team <technicalsupport@solarwinds.com>'

USER root
ARG DEBIAN_FRONTEND=noninteractive
ARG swisnap_repo=swisnap

ENV SNAP_URL=http://127.0.0.1:21413

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get -y install \
      apt-transport-https \
      ca-certificates \
      curl \
      docker.io \
      gnupg && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN arch="$(uname -m)" && if [ "${arch}" = "aarch64" ]; then \
      yq_arch=arm64; \
    elif [ "${arch}" = "x86_64" ]; then \
      yq_arch=amd64; \ 
    fi && \ 
    curl -L "https://github.com/mikefarah/yq/releases/download/3.4.1/yq_linux_${yq_arch}" -o yq && \
    mv yq /usr/bin/yq && \
    chmod +x /usr/bin/yq

ARG swisnap_version
RUN echo "deb https://packagecloud.io/solarwinds/${swisnap_repo}/ubuntu/ focal main" > /etc/apt/sources.list.d/swisnap.list && \
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

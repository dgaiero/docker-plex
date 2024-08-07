# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/unrar:latest AS unrar

FROM ghcr.io/dgaiero/docker-baseimage-ubuntu:mantic

# set version label
ARG BUILD_DATE
ARG VERSION
ARG PLEX_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

#Add needed nvidia environment variables for https://github.com/NVIDIA/nvidia-docker
ENV NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"

# global environment settings
ENV DEBIAN_FRONTEND="noninteractive" \
  PLEX_DOWNLOAD="https://downloads.plex.tv/plex-media-server-new" \
  PLEX_ARCH="amd64" \
  PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="/config/Library/Application Support" \
  PLEX_MEDIA_SERVER_HOME="/usr/lib/plexmediaserver" \
  PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS="6" \
  PLEX_MEDIA_SERVER_USER="abc" \
  PLEX_MEDIA_SERVER_INFO_VENDOR="Docker" \
  PLEX_MEDIA_SERVER_INFO_DEVICE="Docker Container (LinuxServer.io)"

RUN \
  echo "**** install runtime packages ****" && \
  apt-get update && \
  apt-get install -y \
  jq \
  udev \
  git \
  cmake \
  pkg-config \
  meson \
  libdrm-dev \
  automake \
  libtool \
  pciutils \
  vainfo \
  intel-gpu-tools \
  intel-media-va-driver-non-free \
  wget && \
  echo "**** installing Intel Drivers ****" && \
  wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
  gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg && \
  wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | \
  gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg && \
  echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | \
  tee /etc/apt/sources.list.d/intel-gpu-jammy.list && \
  apt update && \
  apt install -y \
  intel-opencl-icd intel-level-zero-gpu level-zero \
  intel-media-va-driver-non-free libmfx1 libmfxgen1 libvpl2 \
  libegl-mesa0 libegl1-mesa libegl1-mesa-dev libgbm1 libgl1-mesa-dev libgl1-mesa-dri \
  libglapi-mesa libgles2-mesa-dev libglx-mesa0 libigdgmm12 libxatracker2 mesa-va-drivers \
  mesa-vdpau-drivers mesa-vulkan-drivers va-driver-all vainfo hwinfo clinfo && \
  echo "**** install libva ****" && \
  git clone https://github.com/intel/libva.git && \
  cd libva && \
  ./autogen.sh --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu && \
  make && \
  make install && \
  echo "**** install plex ****" && \
  if [ -z ${PLEX_RELEASE+x} ]; then \
  PLEX_RELEASE=$(curl -sX GET 'https://plex.tv/api/downloads/5.json' \
  | jq -r '.computer.Linux.version'); \
  fi && \
  curl -o \
  /tmp/plexmediaserver.deb -L \
  "${PLEX_DOWNLOAD}/${PLEX_RELEASE}/debian/plexmediaserver_${PLEX_RELEASE}_${PLEX_ARCH}.deb" && \
  dpkg -i /tmp/plexmediaserver.deb && \
  echo "**** ensure abc user's home folder is /app ****" && \
  usermod -d /app abc && \
  echo "**** cleanup ****" && \
  apt-get clean && \
  rm -rf \
  /etc/default/plexmediaserver \
  /tmp/* \
  /var/lib/apt/lists/* \
  /var/tmp/*

# add local files
COPY root/ /

# add unrar
COPY --from=unrar /usr/bin/unrar-ubuntu /usr/bin/unrar

# ports and volumes
EXPOSE 32400/tcp 1900/udp 5353/udp 8324/tcp 32410/udp 32412/udp 32413/udp 32414/udp 32469/tcp
VOLUME /config

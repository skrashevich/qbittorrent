# syntax=docker/dockerfile:labs
ARG UPSTREAM_IMAGE
ARG UPSTREAM_DIGEST_ARM64

FROM ubuntu:latest as builder
ARG FULL_VERSION
ENV qbt_build_tool qmake
ENV qbt_cross_name aarch64
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y curl
WORKDIR /build12
ENV libtorrent_version "1.2"
RUN curl -sL git.io/qbstatic | bash -s all -qt ${FULL_VERSION} -i -c -b "/build12"

WORKDIR /build20
ENV libtorrent_version "2.0"
RUN curl -sL git.io/qbstatic | bash -s all -qt ${FULL_VERSION} -i -c -b "/build20"


FROM ${UPSTREAM_IMAGE}@${UPSTREAM_DIGEST_ARM64}
EXPOSE 8080
ENV VPN_ENABLED="false" VPN_LAN_NETWORK="" VPN_CONF="wg0" VPN_ADDITIONAL_PORTS="" WEBUI_PORTS="8080/tcp,8080/udp" PRIVOXY_ENABLED="false" S6_SERVICES_GRACETIME=180000

VOLUME ["${CONFIG_DIR}"]

RUN ln -s "${CONFIG_DIR}" "${APP_DIR}/qBittorrent"

RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/main privoxy iptables iproute2 openresolv wireguard-tools && \
    apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community ipcalc && \
    apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing wireguard-go

#ARG FULL_VERSION

#RUN curl -fsSL "https://github.com/userdocs/qbittorrent-nox-static/releases/download/${FULL_VERSION}/x86_64-qbittorrent-nox" > "${APP_DIR}/qbittorrent-nox" && \
COPY --from=builder --link /build12/bin/qbittorrent-nox ${APP_DIR}/qbittorrent-nox-libtorrent12
COPY --from=builder --link /build20/bin/qbittorrent-nox ${APP_DIR}/qbittorrent-nox-libtorrent20
RUN chmod 755 "${APP_DIR}/qbittorrent-nox-libtorrent12" && ln -s "$APP_DIR/qbittorrent-nox-libtorrent12" "$APP_DIR/qbittorrent"
RUN chmod 755 "${APP_DIR}/qbittorrent-nox-libtorrent20"

ARG VUETORRENT_VERSION
RUN curl -fsSL "https://github.com/wdaan/vuetorrent/releases/download/v${VUETORRENT_VERSION}/vuetorrent.zip" > "/tmp/vuetorrent.zip" && \
    unzip "/tmp/vuetorrent.zip" -d "${APP_DIR}" && \
    rm "/tmp/vuetorrent.zip" && \
    chmod -R u=rwX,go=rX "${APP_DIR}/vuetorrent"

COPY root/ /
RUN chmod -R +x /etc/cont-init.d/ /etc/services.d/ /etc/cont-finish.d/
ADD --link https://raw.githubusercontent.com/nbusseneau/qBittorrent-RuTracker-plugin/master/rutracker.py /config/data/nova3/rutracker.py

ENV LIBTORRENTVER=12

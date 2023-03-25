# syntax=docker/dockerfile:labs
ARG UPSTREAM_IMAGE
ARG UPSTREAM_DIGEST_ARM64
ARG FULL_VERSION

FROM --platform=$BUILDPLATFORM node:16 as qb-web-builder
ADD https://github.com/CzBiX/qb-web.git /src
WORKDIR /src
RUN yarn install
RUN yarn run build

FROM ubuntu:latest as builder-base
ENV qbt_build_tool qmake
ENV qbt_cross_name aarch64
ENV DEBIAN_FRONTEND=noninteractive

RUN rm -f /etc/apt/apt.conf.d/docker-clean \
  && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' >/etc/apt/apt.conf.d/keep-cache

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt update --allow-insecure-repositories
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt install -y --no-install-recommends ca-certificates
RUN update-ca-certificates
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt install -y curl build-essential git python3 python3-dev python3-numpy automake pkg-config gawk bison file gettext gettext-base libauthen-sasl-perl \
  libclone-perl libdata-dump-perl libencode-locale-perl libfile-listing-perl libfont-afm-perl libhtml-form-perl libhtml-format-perl \
  libhtml-parser-perl libhtml-tagset-perl libhtml-tree-perl libhttp-cookies-perl libhttp-daemon-perl libhttp-date-perl libhttp-message-perl libhttp-negotiate-perl libio-html-perl \
  libio-socket-ssl-perl libltdl-dev libltdl7 liblwp-mediatypes-perl liblwp-protocol-https-perl libmagic-mgc libmagic1 libmailtools-perl libnet-http-perl libnet-smtp-ssl-perl libnet-ssleay-perl \
  libtext-unidecode-perl libtimedate-perl libtool libtry-tiny-perl liburi-perl libwww-perl libwww-robotrules-perl libxml-libxml-perl libxml-namespacesupport-perl libxml-parser-perl \
  libxml-sax-base-perl libxml-sax-expat-perl libxml-sax-perl perl-openssl-defaults tex-common texinfo

FROM builder-base as builder12
ARG FULL_VERSION
WORKDIR /build12
ENV qbt_libtorrent_version "1.2"
RUN --mount=type=cache,target=/build12/qbt-build curl -sL git.io/qbstatic | sed -e 's/ftp.gnu.org/mirrors.kernel.org/g' | bash -s all -qt ${FULL_VERSION} -i -c -b "/build12"

FROM builder-base as builder20
ARG FULL_VERSION
WORKDIR /build20
ENV qbt_libtorrent_version "2.0"
RUN --mount=type=cache,target=/build20/qbt-build curl -sL git.io/qbstatic | sed -e 's/ftp.gnu.org/mirrors.kernel.org/g' | bash -s all -qt ${FULL_VERSION} -i -c -b "/build20"


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
COPY --from=builder12 --link /build12/bin/qbittorrent-nox ${APP_DIR}/qbittorrent-nox-libtorrent12
COPY --from=builder20 --link /build20/bin/qbittorrent-nox ${APP_DIR}/qbittorrent-nox-libtorrent20
RUN chmod 755 "${APP_DIR}/qbittorrent-nox-libtorrent12" && ln -s "$APP_DIR/qbittorrent-nox-libtorrent12" "$APP_DIR/qbittorrent"
RUN chmod 755 "${APP_DIR}/qbittorrent-nox-libtorrent20"

ARG VUETORRENT_VERSION
RUN curl -fsSL "https://github.com/wdaan/vuetorrent/releases/download/v${VUETORRENT_VERSION}/vuetorrent.zip" > "/tmp/vuetorrent.zip" && \
    unzip "/tmp/vuetorrent.zip" -d "${APP_DIR}" && \
    rm "/tmp/vuetorrent.zip" && \
    chmod -R u=rwX,go=rX "${APP_DIR}/vuetorrent"

COPY --link --from=qb-web-builder /src/dist/public ${APP_DIR}/qb-web

COPY root/ /
RUN chmod -R +x /etc/cont-init.d/ /etc/services.d/ /etc/cont-finish.d/
ADD --link https://raw.githubusercontent.com/nbusseneau/qBittorrent-RuTracker-plugin/master/rutracker.py /config/data/nova3/rutracker.py

ENV LIBTORRENTVER=12

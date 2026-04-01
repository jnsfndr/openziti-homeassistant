ARG BUILD_FROM=ghcr.io/hassio-addons/debian-base/amd64:stable
FROM ${BUILD_FROM}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG BUILD_ARCH
ARG ZET_VERSION="1.11.1"

# Install runtime dependencies and download pre-built ziti-edge-tunnel binary
# Using Debian base image because ziti-edge-tunnel binaries are glibc-linked
# (Alpine uses musl libc which is incompatible — missing libresolv symbols)
RUN \
    case "${BUILD_ARCH}" in \
        "amd64")    ZET_ARCH="x86_64" ;; \
        "aarch64")  ZET_ARCH="arm64"  ;; \
        "armv7")    ZET_ARCH="arm"    ;; \
        *)          echo "Unsupported architecture: ${BUILD_ARCH}" && exit 1 ;; \
    esac \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        iproute2 \
        dnsutils \
        jq \
        curl \
        socat \
        procps \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/openziti \
    && curl -fsSL \
        "https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v${ZET_VERSION}/ziti-edge-tunnel-Linux_${ZET_ARCH}.zip" \
        -o /tmp/zet.zip \
    && unzip /tmp/zet.zip -d /opt/openziti/ \
    && chmod +x /opt/openziti/ziti-edge-tunnel \
    && rm -f /tmp/zet.zip \
    && groupadd --system --gid 2171 ziti \
    && mkdir -m0777 /ziti-edge-tunnel \
    && mkdir -p /opt/openziti/etc/identities \
    && chown -R root:ziti /opt/openziti \
    && chmod -R ug=rwX,o-rwx /opt/openziti/etc/identities

COPY rootfs /

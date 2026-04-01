ARG BUILD_FROM=ghcr.io/hassio-addons/base/amd64:stable
FROM ${BUILD_FROM}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG BUILD_ARCH
ARG ZET_VERSION="1.11.1"

# Install runtime dependencies and download pre-built ziti-edge-tunnel binary
# Packages aligned with official openziti/ziti-edge-tunnel image:
#   iproute2 = iproute (Alpine), procps for debugging (ps, top), jq, socat for IPC socket queries
RUN \
    case "${BUILD_ARCH}" in \
        "amd64")    ZET_ARCH="x86_64" ;; \
        "aarch64")  ZET_ARCH="arm64"  ;; \
        "armv7")    ZET_ARCH="arm"    ;; \
        *)          echo "Unsupported architecture: ${BUILD_ARCH}" && exit 1 ;; \
    esac \
    && apk add --no-cache \
        iproute2 \
        bind-tools \
        jq \
        curl \
        socat \
        procps \
    && mkdir -p /opt/openziti \
    && curl -fsSL \
        "https://github.com/openziti/ziti-tunnel-sdk-c/releases/download/v${ZET_VERSION}/ziti-edge-tunnel-Linux_${ZET_ARCH}.zip" \
        -o /tmp/zet.zip \
    && unzip /tmp/zet.zip -d /opt/openziti/ \
    && chmod +x /opt/openziti/ziti-edge-tunnel \
    && rm -f /tmp/zet.zip \
    && addgroup -S -g 2171 ziti \
    && mkdir -m0777 /ziti-edge-tunnel \
    && mkdir -p /opt/openziti/etc/identities \
    && chown -R root:ziti /opt/openziti \
    && chmod -R ug=rwX,o-rwx /opt/openziti/etc/identities

COPY rootfs /

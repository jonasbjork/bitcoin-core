#
# Bitcoin Core Dockerfile — UBI 10 Minimal, rootless, GPG-verified
# Use make build, see README.md for details.
#
FROM registry.access.redhat.com/ubi10/ubi-minimal@sha256:2a4785f399dc7ae2f3ca85f68bac0ccac47f3e73464a47c21e4f7ae46b55a053 AS build

ARG BITCOIN_VERSION=31.0
ARG ARCH=x86_64
ARG IMAGE_NAME=bitcoin-core
ARG TAG=${BITCOIN_VERSION}

ENV BITCOIN_TARBALL=bitcoin-${BITCOIN_VERSION}-${ARCH}-linux-gnu.tar.gz
ENV BITCOIN_URL=https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/${BITCOIN_TARBALL}
ENV BITCOIN_SUMS_URL=https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS
ENV BITCOIN_SUMS_ASC_URL=https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN microdnf install -y --setopt=install_weak_deps=0 \
        tar-2:1.35-9.el10_1 gzip-1.13-3.el10 gnupg2-2.4.5-4.el10_1 git-core-2.47.3-1.el10_0 \
    && microdnf clean all

RUN set -eux; \
    git clone --depth 1 --filter=blob:none --sparse \
        https://github.com/bitcoin-core/guix.sigs.git /tmp/guix.sigs
WORKDIR /tmp/guix.sigs
RUN git sparse-checkout set builder-keys; \
    gpg --import /tmp/guix.sigs/builder-keys/*.gpg;
WORKDIR /tmp
RUN rm -rf /tmp/guix.sigs
 
RUN set -eux; \
    curl -fsSL "${BITCOIN_URL}"          -o /tmp/${BITCOIN_TARBALL}; \
    curl -fsSL "${BITCOIN_SUMS_URL}"     -o /tmp/SHA256SUMS; \
    curl -fsSL "${BITCOIN_SUMS_ASC_URL}" -o /tmp/SHA256SUMS.asc
 
RUN set -eux; \
    gpg --verify /tmp/SHA256SUMS.asc /tmp/SHA256SUMS;
WORKDIR /tmp
RUN grep "${BITCOIN_TARBALL}" SHA256SUMS | sha256sum -c -
    
 
RUN set -eux; \
    tar -xzf /tmp/${BITCOIN_TARBALL} -C /opt/; \
    ln -s /opt/bitcoin-${BITCOIN_VERSION} /opt/bitcoin; \
    rm -f /tmp/${BITCOIN_TARBALL} /tmp/SHA256SUMS /tmp/SHA256SUMS.asc

# ----- UBI 10 Minimal, rootless, GPG-verified -----
FROM registry.access.redhat.com/ubi10/ubi-minimal@sha256:2a4785f399dc7ae2f3ca85f68bac0ccac47f3e73464a47c21e4f7ae46b55a053

ARG BITCOIN_VERSION=31.0

LABEL maintainer="jonas.bjork@gmail.com"
LABEL description="Bitcoin Core ${BITCOIN_VERSION} — UBI 10 Minimal, rootless, GPG-verified"
LABEL url="https://bitcoincore.org/"
LABEL repository="https://github.com/jonasbjork/bitcoin-core"
LABEL version="${BITCOIN_VERSION}"

# shadow-utils is needed for useradd/group
RUN microdnf install -y --setopt=install_weak_deps=0 shadow-utils-2:4.15.0-10.el10_1 \
    && microdnf clean all

COPY --from=build /opt/bitcoin /opt/bitcoin
ENV PATH="/opt/bitcoin/bin:${PATH}"
 
RUN groupadd -g 1001 bitcoin \
    && useradd -u 1001 -g bitcoin -m -d /home/bitcoin -s /sbin/nologin bitcoin
 
RUN mkdir -p /home/bitcoin/.bitcoin \
    && chown -R 1001:1001 /home/bitcoin/.bitcoin \
    && chmod 700 /home/bitcoin/.bitcoin

# Remove setuid/setgid bits for security hardening
RUN find /usr -perm /6000 -type f -exec chmod a-s {} +

# Volume for blockchain data
VOLUME ["/home/bitcoin/.bitcoin"]
 
# P2P and RPC ports
EXPOSE 8333 8332
 
USER 1001
WORKDIR /home/bitcoin
HEALTHCHECK --interval=60s --timeout=10s --start-period=120s --retries=3 \
    CMD bitcoin-cli -datadir=/home/bitcoin/.bitcoin getblockchaininfo > /dev/null 2>&1 || exit 1
 
ENTRYPOINT ["bitcoind"]
CMD ["-datadir=/home/bitcoin/.bitcoin"]

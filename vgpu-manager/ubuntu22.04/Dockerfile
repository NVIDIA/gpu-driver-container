FROM nvcr.io/nvidia/cuda:13.3.1-base-ubuntu22.04

ARG DRIVER_VERSION
ENV DRIVER_VERSION=$DRIVER_VERSION
ARG DRIVER_ARCH=x86_64
ENV DRIVER_ARCH=$DRIVER_ARCH
ARG GIT_COMMIT=""

# Optional: inject custom CA certificates so apt can verify TLS when building
# behind a corporate MITM proxy. Drop one or more *.crt files into the build
# context's "certs/" directory (the default), or override CUSTOM_CA_CERTS_DIR
# with a path to a different directory inside the build context. When the
# directory is empty, this is a no-op.
ARG CUSTOM_CA_CERTS_DIR=certs
COPY ${CUSTOM_CA_CERTS_DIR}/ /usr/local/share/ca-certificates/
RUN update-ca-certificates

# Remove cuda repository to avoid GPG errors
RUN rm /etc/apt/sources.list.d/cuda*.list

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils \
        build-essential \
        file \
        kmod \
        pciutils && \
    rm -rf /var/lib/apt/lists/*

# Install the gcc-12 package in Ubuntu 22.04 as Kernels with versions 5.19.x and 6.5.x need gcc 12.3.0 for compilation
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc-12 g++-12 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 12 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 12 && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy main universe" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates main universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-security main universe" >> /etc/apt/sources.list && \
    usermod -o -u 0 -g 0 _apt

RUN mkdir -p /driver
WORKDIR /driver
ADD NVIDIA-Linux-${DRIVER_ARCH}-${DRIVER_VERSION}-vgpu-kvm.run .
RUN chmod +x NVIDIA-Linux-${DRIVER_ARCH}-${DRIVER_VERSION}-vgpu-kvm.run

# Install NVIDIA Fabric Manager (with its NSCQ / NVSDM / NVLink Subnet Manager
# dependencies) so the entrypoint can start it on NVSwitch (HGX) hosts. On
# SR-IOV vGPU systems Fabric Manager must run in vGPU multitenancy mode
# (FABRIC_MODE=2); the entrypoint writes that mode into fabricmanager.cfg before
# starting the daemon. This mirrors how the non-vGPU driver image installs these
# packages (see ../../ubuntu22.04/install.sh). The daemon stays dormant on
# non-NVSwitch hosts because the entrypoint only starts it when NVSwitch devices
# are present.
#
# Packages are bounded to the driver's major branch (=<branch>.*) rather than
# pinned to the exact driver version as the non-vGPU image does: vGPU host-driver
# patch versions are not published one-to-one as public Fabric Manager packages,
# so an exact pin would fail to resolve. The branch bound keeps builds
# reproducible and avoids pulling a newer-branch Fabric Manager against an older
# driver.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg && \
    curl -fSsL "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb" -o /tmp/cuda-keyring.deb && \
    dpkg -i /tmp/cuda-keyring.deb && rm -f /tmp/cuda-keyring.deb && \
    apt-get update && \
    DRIVER_BRANCH="${DRIVER_VERSION%%.*}" && \
    if [ "${DRIVER_BRANCH}" -ge 580 ]; then \
        fm_pkg="nvidia-fabricmanager"; nscq_pkg="libnvidia-nscq"; nvsdm_pkg="libnvsdm"; \
    else \
        fm_pkg="nvidia-fabricmanager-${DRIVER_BRANCH}"; nscq_pkg="libnvidia-nscq-${DRIVER_BRANCH}"; nvsdm_pkg="libnvsdm-${DRIVER_BRANCH}"; \
    fi && \
    apt-get install -y --no-install-recommends "${fm_pkg}=${DRIVER_BRANCH}.*" "${nscq_pkg}=${DRIVER_BRANCH}.*" && \
    apt-mark hold "${fm_pkg}" "${nscq_pkg}" && \
    if [ "${DRIVER_BRANCH}" -ge 570 ]; then \
        apt-get install -y --no-install-recommends "${nvsdm_pkg}=${DRIVER_BRANCH}.*" nvlsm infiniband-diags && \
        apt-mark hold "${nvsdm_pkg}"; \
    fi && \
    rm -f /etc/apt/sources.list.d/cuda*.list /etc/apt/sources.list.d/cuda*.sources && \
    rm -rf /var/lib/apt/lists/*

COPY nvidia-driver /usr/local/bin

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        apt-get update && apt-get --only-upgrade -y install ${CVE_UPDATES} && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Add NGC DL license from the CUDA image
RUN mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

LABEL io.k8s.display-name="NVIDIA vGPU Manager Container"
LABEL name="NVIDIA vGPU Manager Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL vcs-ref="${GIT_COMMIT}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA vGPU Manager (host driver) through containers"
LABEL description="See summary"

ENTRYPOINT ["nvidia-driver", "init"]

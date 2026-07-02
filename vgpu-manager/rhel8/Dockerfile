FROM nvcr.io/nvidia/cuda:13.3.0-base-ubi8

ARG DRIVER_VERSION
ENV DRIVER_VERSION=$DRIVER_VERSION
ARG DRIVER_ARCH=x86_64
ENV DRIVER_ARCH=$DRIVER_ARCH
ARG GIT_COMMIT=""

# Optional: inject custom CA certificates so package managers (dnf/yum) can
# verify TLS when building behind a corporate MITM proxy. Drop one or more
# *.crt files into the build context's "certs/" directory (the default), or
# override CUSTOM_CA_CERTS_DIR with a path to a different directory inside
# the build context. When the directory is empty, this is a no-op.
ARG CUSTOM_CA_CERTS_DIR=certs
COPY ${CUSTOM_CA_CERTS_DIR}/ /etc/pki/ca-trust/source/anchors/
RUN update-ca-trust

RUN mkdir -p /driver
WORKDIR /driver
COPY NVIDIA-Linux-${DRIVER_ARCH}-${DRIVER_VERSION}-vgpu-kvm.run .
RUN chmod +x NVIDIA-Linux-${DRIVER_ARCH}-${DRIVER_VERSION}-vgpu-kvm.run

COPY nvidia-driver /usr/local/bin
COPY ocp_dtk_entrypoint /usr/local/bin

RUN dnf install -y pciutils && \
    dnf clean all && \
    rm -rf /var/cache/dnf/*

LABEL io.k8s.display-name="NVIDIA vGPU Manager Container"
LABEL name="NVIDIA vGPU Manager Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL vcs-ref="${GIT_COMMIT}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA vGPU Manager through containers"
LABEL description="See summary"

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
    dnf update -y ${CVE_UPDATES} && \
    dnf clean all; \
    fi

# Add NGC DL license from the CUDA image
RUN mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

ENTRYPOINT ["nvidia-driver", "init"]

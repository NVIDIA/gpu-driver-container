FROM nvcr.io/nvidia/cuda:12.9.1-base-ubi8

ARG DRIVER_VERSION
ENV DRIVER_VERSION=$DRIVER_VERSION
ARG DRIVER_ARCH=x86_64
ENV DRIVER_ARCH=$DRIVER_ARCH

RUN mkdir -p /driver
WORKDIR /driver
COPY NVIDIA-Linux-${DRIVER_ARCH}-${DRIVER_VERSION}-vgpu-kvm.run .
RUN chmod +x NVIDIA-Linux-${DRIVER_ARCH}-${DRIVER_VERSION}-vgpu-kvm.run

COPY nvidia-driver /usr/local/bin
COPY ocp_dtk_entrypoint /usr/local/bin

LABEL io.k8s.display-name="NVIDIA vGPU Manager Container"
LABEL name="NVIDIA vGPU Manager Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA vGPU Manager through containers"
LABEL description="See summary"

# Install / upgrade packages here that are required to resolve CVEs
ARG CVE_UPDATES
RUN if [ -n "${CVE_UPDATES}" ]; then \
        yum update -y ${CVE_UPDATES} && \
        rm -rf /var/cache/yum/*; \
    fi

# Add NGC DL license from the CUDA image
RUN mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

ENTRYPOINT ["nvidia-driver", "init"]

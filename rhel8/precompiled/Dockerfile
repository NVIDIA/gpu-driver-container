ARG DRIVER_TOOLKIT_IMAGE=''
ARG CUDA_DIST=''

FROM ${DRIVER_TOOLKIT_IMAGE} as builder

ARG BASE_URL='https://us.download.nvidia.com/tesla'
ARG KERNEL_VERSION=''
ARG DRIVER_VERSION=''
ARG DRIVER_EPOCH=''
ARG BUILDER_USER=''
ARG BUILDER_EMAIL=''
ARG RHEL_VERSION=''

RUN useradd -u 1001 -m -s /bin/bash builder

USER builder

WORKDIR /home/builder
COPY --chown=1001:0 x509-configuration.ini private_key.priv* public_key.der* /home/builder/

RUN export KVER=$(echo ${KERNEL_VERSION} | cut -d '-' -f 1) \
        TARGET_ARCH=${KERNEL_VERSION##*.} \
        KREL=$(echo ${KERNEL_VERSION} | cut -d '-' -f 2 | sed 's/\.el._.\..\+$//') \
        KDIST=$(echo ${KERNEL_VERSION} | cut -d '-' -f 2 | sed 's/^.*\(\.el._.\)\..\+$/\1/') \
        DRIVER_STREAM=$(echo ${DRIVER_VERSION} | cut -d '.' -f 1) \
        RHEL_VERSION_MAJOR=$(echo ${RHEL_VERSION} | cut -d '.' -f 1) \
    && curl -sLOf ${BASE_URL}/${DRIVER_VERSION}/NVIDIA-Linux-${TARGET_ARCH}-${DRIVER_VERSION}.run \
    && git clone --depth 1 --single-branch -b rhel${RHEL_VERSION_MAJOR} https://github.com/NVIDIA/yum-packaging-precompiled-kmod \
    && cd yum-packaging-precompiled-kmod \
    && mkdir BUILD BUILDROOT RPMS SRPMS SOURCES SPECS \
    && mkdir nvidia-kmod-${DRIVER_VERSION}-${TARGET_ARCH} \
    && sh ${HOME}/NVIDIA-Linux-${TARGET_ARCH}-${DRIVER_VERSION}.run --extract-only --target tmp \
    && mv tmp/kernel nvidia-kmod-${DRIVER_VERSION}-${TARGET_ARCH}/ \
    && tar -cJf SOURCES/nvidia-kmod-${DRIVER_VERSION}-${TARGET_ARCH}.tar.xz nvidia-kmod-${DRIVER_VERSION}-${TARGET_ARCH} \
    && mv kmod-nvidia.spec SPECS/ \
    && if test -f "/home/builder/private_key.priv" -a -f "/home/builder/public_key.der" ; then \
        mv /home/builder/private_key.priv /home/builder/public_key.der SOURCES ; \
    else \
        sed -i -e "s/\$USER/${BUILDER_USER}/" -e "s/\$EMAIL/${BUILDER_EMAIL}/" ${HOME}/x509-configuration.ini ; \
        openssl req -x509 -new -nodes -utf8 -sha256 -days 36500 -batch \
            -config ${HOME}/x509-configuration.ini \
            -outform DER -out SOURCES/public_key.der \
            -keyout SOURCES/private_key.priv ; \
    fi \
    && rpmbuild \
        --define "%_topdir $(pwd)" \
        --define "debug_package %{nil}" \
        --define "kernel ${KVER}" \
        --define "kernel_release ${KREL}" \
        --define "kernel_dist ${KDIST}" \
        --define "driver ${DRIVER_VERSION}" \
        --define "epoch ${DRIVER_EPOCH}" \
        --define "driver_branch ${DRIVER_STREAM}" \
        -v -bb SPECS/kmod-nvidia.spec

FROM nvcr.io/nvidia/cuda:12.6.2-base-${CUDA_DIST}

ARG KERNEL_VERSION=''
ARG RHEL_VERSION=''

ARG DRIVER_TYPE=passthrough
ENV DRIVER_TYPE=${DRIVER_TYPE}

ARG DRIVER_VERSION=''
ENV DRIVER_VERSION=${DRIVER_VERSION}

ARG TARGET_ARCH=''
ENV TARGETARCH=${TARGET_ARCH}

# Force using provided RHSM registration
ENV SMDEV_CONTAINER_OFF=1

# Disable vGPU version compability check by default
ARG DISABLE_VGPU_VERSION_CHECK=true
ENV DISABLE_VGPU_VERSION_CHECK=$DISABLE_VGPU_VERSION_CHECK

USER root

COPY --chmod=744 nvidia-driver /usr/local/bin
COPY --chmod=744 common.sh /usr/local/bin

# Copy the built NVIDIA driver RPM from the builder
COPY --from=builder /home/builder/yum-packaging-precompiled-kmod/RPMS/${TARGET_ARCH}/*.rpm /rpms/

# Copy the DRM module dependency from the builder
COPY --from=builder /lib/modules/${KERNEL_VERSION}/kernel/drivers/gpu/drm/drm.ko.xz /lib/modules/${KERNEL_VERSION}/kernel/drivers/gpu/drm/

# Kernel packages needed to build drivers / kmod
RUN echo "${RHEL_VERSION}" > /etc/dnf/vars/releasever \
    && dnf config-manager --best --nodocs --setopt=install_weak_deps=False --save \
    && DRIVER_STREAM=$(echo ${DRIVER_VERSION} | cut -d '.' -f 1) \
    && dnf -y module enable nvidia-driver:${DRIVER_STREAM}/default \
    && dnf -y install kmod binutils

# Prevent modprobe from giving a WARNING about missing files
RUN rm -rf /lib/modules/${KERNEL_VERSION} \
    && mkdir -p /lib/modules/${KERNEL_VERSION}/proc \
    && touch /lib/modules/${KERNEL_VERSION}/modules.order \
    && touch /lib/modules/${KERNEL_VERSION}/modules.builtin \
    && depmod ${KERNEL_VERSION}

# Install the Driver modules
RUN dnf install -y /rpms/kmod-nvidia-*.rpm

# Copy the rhsm-register script to enable subscription-manager during build time
COPY --chmod=744 ./rhsm-register /usr/local/bin/rhsm-register

RUN --mount=type=secret,id=RHSM_ORG,target=/run/secrets/RHSM_ORG \
    --mount=type=secret,id=RHSM_ACTIVATIONKEY,target=/run/secrets/RHSM_ACTIVATIONKEY \
    CUDA_VERSION_ARRAY=(${CUDA_VERSION//./ }) && CUDA_DASHED_VERSION=${CUDA_VERSION_ARRAY[0]}-${CUDA_VERSION_ARRAY[1]} \
    && rm /etc/rhsm-host \
    && /usr/local/bin/rhsm-register \
    && dnf install -y \
        nvidia-driver-cuda-${DRIVER_VERSION} \
	    nvidia-driver-libs-${DRIVER_VERSION} \
	    nvidia-driver-NVML-${DRIVER_VERSION} \
        cuda-compat-${CUDA_DASHED_VERSION} \
        cuda-cudart-${CUDA_DASHED_VERSION}

RUN if [ "$DRIVER_TYPE" != "vgpu" ]; then \
        VERSION_ARRAY=(${DRIVER_VERSION//./ }) \
        && if [ ${VERSION_ARRAY[0]} -ge 470 ] || ([ ${VERSION_ARRAY[0]} == 460 ] && [ ${VERSION_ARRAY[1]} -ge 91 ]) \
        then \
            FABRIC_MANAGER_VERSION=${DRIVER_VERSION}-1 ; \
        else \
            FABRIC_MANAGER_VERSION=${VERSION_ARRAY[0]}-${DRIVER_VERSION}-1 ; \
        fi \
        && NSCQ_VERSION=${VERSION_ARRAY[0]}-${DRIVER_VERSION}-1 \
        && dnf install -y \
            nvidia-fabric-manager-${FABRIC_MANAGER_VERSION} \
            libnvidia-nscq-${NSCQ_VERSION}; \
    fi

RUN dnf clean all \
    && subscription-manager unregister

LABEL io.k8s.display-name="NVIDIA Driver Container"
LABEL name="NVIDIA Driver Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL release="N/A"
LABEL summary="Provision the NVIDIA driver through containers"
LABEL description="See summary"

# Add NGC DL license from the CUDA image
RUN mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/yum.repos.d/cuda.repo

ENTRYPOINT ["nvidia-driver", "init"]

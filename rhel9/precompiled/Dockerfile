ARG DRIVER_TOOLKIT_IMAGE
ARG CUDA_VERSION
ARG CUDA_DIST

FROM ${DRIVER_TOOLKIT_IMAGE} as builder

ARG BASE_URL='https://us.download.nvidia.com/tesla'

ARG KERNEL_VERSION=''
ARG RHEL_VERSION=''
ARG RHEL_VERSION_MAJOR=''

ARG BUILD_ARCH=''
ARG TARGET_ARCH=''

ARG DRIVER_VERSION=''
ARG DRIVER_EPOCH=''
ARG DRIVER_OPEN='false'
ARG DRIVER_PATH='kernel'

ARG BUILDER_USER=''
ARG BUILDER_EMAIL=''
ARG DRIVER_STREAM_TYPE=''

RUN useradd -u 1001 -m -s /bin/bash builder

USER builder

WORKDIR /home/builder
COPY --chown=1001:0 x509-configuration.ini private_key.priv* public_key.der* /home/builder/

RUN export KVER=$(echo ${KERNEL_VERSION} | cut -d '-' -f 1) \
        KREL=$(echo ${KERNEL_VERSION} | cut -d '-' -f 2 | sed 's/\.el._.\..\+$//') \
        KDIST=$(echo ${KERNEL_VERSION} | cut -d '-' -f 2 | sed 's/^.*\(\.el._.\)\..\+$/\1/') \
        DRIVER_STREAM=$(echo ${DRIVER_VERSION} | cut -d '.' -f 1) \
    && if [ "${DRIVER_OPEN}" == "true" ] ; then export DRIVER_PATH="${DRIVER_PATH}-open" ; fi \
    && git clone --depth 1 --single-branch -b rhel${RHEL_VERSION_MAJOR} https://github.com/NVIDIA/yum-packaging-precompiled-kmod \
    && cd yum-packaging-precompiled-kmod \
    && mkdir BUILD BUILDROOT RPMS SRPMS SOURCES SPECS \
    && mkdir nvidia-kmod-${DRIVER_VERSION}-${BUILD_ARCH} \
    && curl -sLOf ${BASE_URL}/${DRIVER_VERSION}/NVIDIA-Linux-${TARGET_ARCH}-${DRIVER_VERSION}.run \
    && sh ./NVIDIA-Linux-${TARGET_ARCH}-${DRIVER_VERSION}.run --extract-only --target tmp \
    && if [ "${DRIVER_STREAM_TYPE}" == "development" ] ; then \
        export DRIVER_OPEN='true' ; \
        git clone --depth 1 --single-branch -b ${DRIVER_VERSION} https://github.com/NVIDIA/open-gpu-kernel-modules ; \
        mv open-gpu-kernel-modules/${DRIVER_PATH} nvidia-kmod-${DRIVER_VERSION}-${BUILD_ARCH}/kernel ; \
    else \
        mv tmp/${DRIVER_PATH} nvidia-kmod-${DRIVER_VERSION}-${BUILD_ARCH}/kernel ; \
    fi \
    && tar -cJf SOURCES/nvidia-kmod-${DRIVER_VERSION}-${BUILD_ARCH}.tar.xz nvidia-kmod-${DRIVER_VERSION}-${BUILD_ARCH} \
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
        --define "% _arch ${BUILD_ARCH}" \
        --define "%_topdir $(pwd)" \
        --define "debug_package %{nil}" \
        --define "kernel ${KVER}" \
        --define "kernel_release ${KREL}" \
        --define "kernel_dist ${KDIST}" \
        --define "driver ${DRIVER_VERSION}" \
        --define "epoch ${DRIVER_EPOCH}" \
        --define "driver_branch ${DRIVER_STREAM}" \
        -v -bb SPECS/kmod-nvidia.spec

FROM nvcr.io/nvidia/cuda:${CUDA_VERSION}-base-${CUDA_DIST}

ARG BASE_URL='https://us.download.nvidia.com/tesla'

ARG KERNEL_VERSION
ARG KERNEL_VERSION_NOARCH
ARG RHEL_VERSION
ARG OS_TAG

ARG CUDA_VERSION

ARG DRIVER_STREAM_TYPE

ARG DRIVER_TYPE=passthrough
ENV DRIVER_TYPE=${DRIVER_TYPE}

ARG DRIVER_VERSION
ENV DRIVER_VERSION=${DRIVER_VERSION}

ARG BUILD_ARCH
ARG TARGET_ARCH
ENV TARGETARCH=${TARGET_ARCH}

# Force using provided RHSM registration
ENV SMDEV_CONTAINER_OFF=1

# Disable vGPU version compability check by default
ARG DISABLE_VGPU_VERSION_CHECK=true
ENV DISABLE_VGPU_VERSION_CHECK=${DISABLE_VGPU_VERSION_CHECK}

USER root

COPY --chmod=744 nvidia-driver /usr/local/bin
COPY --chmod=744 common.sh /usr/local/bin

# Copy the firmware files
COPY --from=builder --chmod=444 /home/builder/yum-packaging-precompiled-kmod/tmp/firmware/*.bin /opt/lib/firmware/nvidia/${DRIVER_VERSION}/

# Kernel packages needed to build drivers / kmod
RUN echo "${RHEL_VERSION}" > /etc/dnf/vars/releasever \
    && dnf config-manager --best --nodocs --setopt=install_weak_deps=False --save \
    && dnf -y install kmod binutils

# Prevent modprobe from giving a WARNING about missing files
RUN rm -rf /lib/modules/${KERNEL_VERSION_NOARCH}.${BUILD_ARCH} \
    && mkdir -p /lib/modules/${KERNEL_VERSION_NOARCH}.${BUILD_ARCH}/proc \
    && touch /lib/modules/${KERNEL_VERSION_NOARCH}.${BUILD_ARCH}/modules.order \
    && touch /lib/modules/${KERNEL_VERSION_NOARCH}.${BUILD_ARCH}/modules.builtin \
    && depmod ${KERNEL_VERSION_NOARCH}.${BUILD_ARCH}

# Copy the DRM module dependency from the builder
COPY --from=builder /lib/modules/${KERNEL_VERSION_NOARCH}.${BUILD_ARCH}/kernel/drivers/gpu/drm/drm.ko.xz /lib/modules/${KERNEL_VERSION_NOARCH}.${BUILD_ARCH}/kernel/drivers/gpu/drm/drm.ko.xz

# Copy the built NVIDIA driver RPM from the builder
COPY --from=builder /home/builder/yum-packaging-precompiled-kmod/RPMS/${TARGET_ARCH}/*.rpm /rpms/

# Install the Driver modules
RUN dnf install -y /rpms/kmod-nvidia-*.rpm \
    && rm -rf /rpms

# Copy the rhsm-register script to enable subscription-manager during build time
COPY --chmod=744 ./rhsm-register /usr/local/bin/rhsm-register

RUN --mount=type=secret,id=RHSM_ORG,target=/run/secrets/RHSM_ORG \
    --mount=type=secret,id=RHSM_ACTIVATIONKEY,target=/run/secrets/RHSM_ACTIVATIONKEY \
    export DRIVER_STREAM=$(echo ${DRIVER_VERSION} | cut -d '.' -f 1) \
    && if [ "${DRIVER_STREAM_TYPE}" == "development" ] ; then \
        curl -sLOf ${BASE_URL}/${DRIVER_VERSION}/NVIDIA-Linux-${TARGET_ARCH}-${DRIVER_VERSION}.run \
        sh ./NVIDIA-Linux-${TARGET_ARCH}-${DRIVER_VERSION}.run \
            --silent \
            --accept-license \
            --no-kernel-modules \
            --no-nvidia-modprobe \
            --no-rebuild-initramfs \
        && rm NVIDIA-Linux-${TARGET_ARCH}-${DRIVER_VERSION}.run ; \
    else \
        CUDA_VERSION_ARRAY=(${CUDA_VERSION//./ }) && CUDA_DASHED_VERSION=${CUDA_VERSION_ARRAY[0]}-${CUDA_VERSION_ARRAY[1]} \
        && rm /etc/rhsm-host \
        && /usr/local/bin/rhsm-register \
        && dnf -y module enable nvidia-driver:${DRIVER_STREAM}-open/default \
        && dnf install -y \
            nvidia-driver-cuda-${DRIVER_VERSION} \
            nvidia-driver-libs-${DRIVER_VERSION} \
            libnvidia-ml-${DRIVER_VERSION} \
            cuda-compat-${CUDA_DASHED_VERSION} \
            cuda-cudart-${CUDA_DASHED_VERSION} \
            nvidia-persistenced-${DRIVER_VERSION} \
        && if [ "$DRIVER_TYPE" != "vgpu" ] && [ "$TARGETARCH" != "arm64" ]; then \
            versionArray=(${DRIVER_VERSION//./ }); \
            DRIVER_BRANCH=${versionArray[0]}; \
            dnf install -y nvidia-fabric-manager-${DRIVER_VERSION} libnvidia-nscq-${DRIVER_BRANCH}-${DRIVER_VERSION} ; \
        fi \
        && subscription-manager unregister ; \
    fi

RUN dnf clean all \
    && rm /usr/local/bin/rhsm-register

LABEL io.k8s.display-name="NVIDIA Driver Container"
LABEL name="NVIDIA Driver Container"
LABEL vendor="NVIDIA"
LABEL version="${DRIVER_VERSION}"
LABEL release="${KERNEL_VERSION}-${OS_TAG}"
LABEL summary="Provision the NVIDIA driver through containers"
LABEL description="See summary"

# Add NGC DL license from the CUDA image
RUN mkdir /licenses && mv /NGC-DL-CONTAINER-LICENSE /licenses/NGC-DL-CONTAINER-LICENSE

# Remove cuda repository to avoid GPG errors
RUN rm -f /etc/yum.repos.d/cuda.repo

ENTRYPOINT ["nvidia-driver", "init"]

# Precompiled NVIDIA GPU driver container image for RHEL 9.x (RHCOS 4.13+)

The procedure is based on [building custom kmod packages](https://github.com/NVIDIA/yum-packaging-precompiled-kmod) to allow support for a wide range of kernel versions.

**Prerequisites**:

* A Red Hat account with access to Red Hat Hybrid Cloud Console and Red Hat Subscription Management (RHSM).
* A machine for each architecture that the image is built for. Cross-compilation is not supported.

## Image build

1. Create a [Red Hat Customer Portal Activation Key](https://access.redhat.com/articles/1378093) and note your Red Hat Subscription Management (RHSM) organization ID. These will be used to install packages during a build. Save the values to file, e.g., `$HOME/rhsm_org` and `$HOME/rhsm_activationkey`, and export the paths to these files.

   ```
   export RHSM_ORG_FILE=$HOME/rhsm_org
   export RHSM_ACTIVATIONKEY_FILE=$HOME/rhsm_activationkey
   ```

2. Download a [Red Hat OpenShift pull secret](https://access.redhat.com/documentation/en-us/openshift_cluster_manager/2023/html/managing_clusters/assembly-managing-clusters#downloading_and_updating_pull_secrets).

   Once you have downloaded the pull secret, put it in a
   `pull-secret.txt` file in the home folder of the user
   building the precompiled driver image and we export the
   path to this file.

   ```
   export PULL_SECRET_FILE=$HOME/pull-secret.txt
   ```

3. Find out the Driver Toolkit (DTK) image for your target Red Hat OpenShift version, e.g.:

   *The Driver Toolkit (DTK from now on) is a container image in the
   OpenShift payload which is meant to be used as a base image on
   which to build driver containers. The Driver Toolkit image contains
   the kernel packages commonly required as dependencies to build or
   install kernel modules as well as a few tools needed in driver
   containers. The version of these packages will match the kernel
   version running on the RHCOS nodes in the corresponding OpenShift
   release.* -- [Driver Toolkit](https://github.com/openshift/driver-toolkit/)

   With that in mind, we can start defining some environment variables
   and get the Driver Toolkit image for the version of OpenShift we
   need to compile the drivers for.

   First, we define the version of OpenShift and the architecture.

   ***Note*** - Red Hat Enterprise Linux 9 provides a kernel compiled
   with 64k page size for `aarch64` architecture. For these builds,
   the version of the kernel is suffixed with `+64k`. Hence, we need
   to differentiate the target architecture, which is `aarch64` and
   the build kernel which is either empty or `+64k`.

   ```
   export OPENSHIFT_VERSION='4.15.0'
   export BUILD_ARCH='aarch64+64k'
   export TARGET_ARCH=$(echo "${BUILD_ARCH}" | sed 's/+64k//')
   ```

   We can now get the Driver Toolkit image for OpenShift.

   ```
   export DRIVER_TOOLKIT_IMAGE=$( \
       oc adm release info --image-for=driver-toolkit \
       quay.io/openshift-release-dev/ocp-release:${OPENSHIFT_VERSION}-${TARGET_ARCH} \
   )
   ```

   Regarding the naming convention, the generating image tag needs to
   contain `rhcos` and the minor version of OpenShift. We export that
   as the `OS_TAG` environment variable.

   ```
   export OS_TAG=rhcos$(echo ${OPENSHIFT_VERSION} | awk -F. '{print $1"."$2}')
   ```

4. Find out the RHEL and kernel version of the target OpenShift cluster.

   Driver Toolkit contains the `/etc/driver-toolkit-release.json` file
   that exposes some information about the RHEL and kernel that Driver
   Toolkit was built for. We can extract them with `podman run` and
   `jq`.

   First, the RHEL version.

   ```
   export RHEL_VERSION=$(podman run --rm -it \
       --authfile ${PULL_SECRET_FILE} \
       ${DRIVER_TOOLKIT_IMAGE} \
       cat /etc/driver-toolkit-release.json \
       | jq -r '.RHEL_VERSION')
   ```

   Then, the kernel version.

   ```
   export KERNEL_VERSION=$(podman run --rm -it \
       --authfile ${PULL_SECRET_FILE} \
       ${DRIVER_TOOLKIT_IMAGE} \
       cat /etc/driver-toolkit-release.json \
       | jq -r '.KERNEL_VERSION')
   ```

5. Set NVIDIA environment variables.

   ```
   export CUDA_VERSION=12.8.1
   export DRIVER_EPOCH=1
   export DRIVER_VERSION=570.133.20
   ```

6. [Optional] Use custom signing keys

   By default, the build process generates self-signed key and certificate,
   because the spec file expects them during the build. It uses the
   `x509-configuration.ini` file to set the OpenSSL configuration. However,
   for Secure Boot, it is recommended to use signing keys that are trusted by
   the machines, i.e. that are part of the authorized keys database.

   To pass custom signing key and certificate during the build, you can put
   them in the current folder as `private_key.priv` for the private key and
   `public_key.der` for the public certificate in DER format. The build process
   will use them if they are present, and fallback to self-signed certificate
   otherwise.

7. [Optional] Build the vGPU guest driver

   To build the vGPU guest driver, set the `DRIVER_TYPE` environment
   variable to `vgpu`. The default is `passthrough`.

8. [Optional] Customize the builder info

   The default container management tool is Docker (`docker`). You can
   override it to use Podman by setting the `CONTAINER_TOOL` environment
   variable to `podman`.

   The default registry is `nvcr.io/ea-cnt` which is limited to NVIDIA.
   You can override it to your own registry via the `IMAGE_REGISTRY`
   environment variable.

   The default image name is `driver` for `passthrough` and
   `vgpu-guest-driver` for vGPU. You can override is by setting the
   `IMAGE_NAME` environment variable.

   You can also override `BUILDER_USER` and/or `BUILDER_EMAIL`. Otherwise,
   your Git username and email will be used.

   See the [Makefile](Makefile) for all available variables.

9. Build and push the image

   ```
   make image image-push
   ```

## NVIDIA GPU operator

In order to be used with the NVIDIA GPU Operator on Red Hat OpenShift,
the image tag must follow the format `${DRIVER_VERSION}-${KERNEL_VERSION}-${OS_TAG}`,
and the full name will look like
`quay.io/acme/nvidia-gpu-driver:550.54.14-5.14.0-284.54.1.el9_2.aarch64_64k-rhcos4.15`.


Define the `NVIDIADDriver` custom resource to make use of the pre-compiled driver image, e.g.:

```
  spec:
    usePrecompiled: true
    repository: quay.io/acme
    image: nvidia-gpu-driver
    version: 550.127.05
```

Define the `ClusterPolicy` resource to make use of the NVIDIADriver custom resource, e.g.:

```
    driver:
      enabled: true
      useNvidiaDriverCRD: true
    validator:
      driver:
        env:
          - name: DISABLE_DEV_CHAR_SYMLINK_CREATION
            value: "true"
```

Examples of full NVIDIADriver and ClusterPolicy custom resources are available in the
[nvdidiadriver.json](nvidiadriver.json) and [clusterpolicy.json](clusterpolicy.json) files.

Find more information in the [Precompiled Driver Containers](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/precompiled-drivers.html) documentation.

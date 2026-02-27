# NVIDIA GPU Driver Container for Fedora & FedoraCoreOS

[FedoraCoreOS (FCOS)](https://getfedora.org/en/coreos?stream=stable) is a self-updating minimal container-optimized Linux distribution downstream of Fedora.

NVIDIA does not yet support FCOS and so the forked Gitlab project [here](https://gitlab.com/container-toolkit-fcos/driver.git) produces Fedora kernel-specific container images.

Since these images are built on FedoraCoreOS gitlab-runners tracking the next/development/stable streams we use the `nvidia-driver update` function to include pre-compiled kernel modules speeding driver startup.

Images are pushed first on a pre-release basis to the in-built GitLab docker registry and pushed to Dockerhub [here](https://hub.docker.com/repository/docker/fifofonix/driver) once security scanned and validated.

When run as a privileged 'driver container' they install/run NVIDIA kernel modules.

See [here](https://github.com/NVIDIA/nvidia-docker/wiki/) for an overview of the overall architecture.

## Supported GPUs/Drivers

NVIDIA datacenter GPUs based on Pascal+ architecture (e.g. P100, V100, T4, A100) running x86 FCOS are supported.

NVIDIA datacenter drivers support a specific CUDA version and have minimum supported Linux kernel constraints.

Currently built driver versions are specified in `ci/fedora/.common-ci-fcos.yml`.

## Getting Started

### Running the Driver Container

The driver container is privileged, and here we choose to launch via podman instead of docker although both work.

```bash
$ DRIVER_VERSION=550.90.07 # Check ci/fedora/.common-ci-fcos.yml for latest driver versions
$ FEDORA_VERSION_ID=$(cat /etc/os-release | grep VERSION_ID | cut -d = -f2)
$ podman run -d --privileged --pid=host \
     -v /run/nvidia:/run/nvidia:shared \
     -v /var/log:/var/log \
     --name nvidia-driver \
     registry.gitlab.com/container-toolkit-fcos/driver:${DRIVER_VERSION}-fedora$$FEDORA_VERSION_ID
```

Or, on FCOS registering as a systemd unit via an ignition snippet. In this unit we attempt to pull a driver image matching the running kernel version (with pre-compiled kernel headers), but fall back to a generic Fedora version if one does not exist. Furthermore, we
mount a single patch file from a host directory that, if detected, will be applied to the generic Fedora version.

```yaml
variant: fcos
version: 1.5.0
systemd:
  units:
    - name: acme-nvidia-driver.service
      enabled: true
      contents: |
        [Unit]
        Requires=network-online.target
        After=network-online.target
        StartLimitInterval=1600
        StartLimitBurst=5
        [Service]
        TimeoutStartSec=250
        ExecStartPre=-/bin/podman stop nvidia-driver
        ExecStartPre=-/bin/podman rm nvidia-driver
        ExecStartPre=-setenforce 0
        ExecStartPre=-/bin/mkdir -p /run/nvidia
        # 5/17/24 - Without the following line the nvidia driver container will crash with no meaningful error message
        ExecStartPre=-/usr/sbin/modprobe video

        # If there is a kernel-specific image (with pre-compiled kernel headers) then
        # use it, otherwise fallback to the generic Fedora image mounting any patches that exist.
        #
        # Replace registry.gitlab.com/container-toolkit-fcos/driver with the registry name
        # of your built/published driver images, or perhaps, docker.io/fifofonix/driver
        ExecStart=/bin/sh -c ' \
          FEDORA_VERSION_ID=$(cat /etc/os-release | grep VERSION_ID | cut -d = -f2); \
          KERNEL_VERSION=$(/bin/uname -r); \
          if /bin/podman manifest inspect registry.gitlab.com/container-toolkit-fcos/driver:550.90.07-$$KERNEL_VERSION-fedora$$FEDORA_VERSION_ID > /dev/null; then \
            IMAGE_NAME=registry.gitlab.com/container-toolkit-fcos/driver:550.90.07-$$KERNEL_VERSION-fedora$$FEDORA_VERSION_ID; \
          else \
            IMAGE_NAME=registry.gitlab.com/container-toolkit-fcos/driver:550.90.07-fedora$$FEDORA_VERSION_ID; \
            PATCH_MOUNT="-v /var/acme/nvidia-driver-patch:/patch"
          fi; \
          /bin/podman pull $$IMAGE_NAME; \
          /bin/podman run --name nvidia-driver \
            -v /run/nvidia:/run/nvidia:shared \
            -v /var/log:/var/log \
            $$PATCH_MOUNT \
            --privileged \
            --pid host \
            $$IMAGE_NAME \
                --accept-license'

        ExecStop=/bin/podman stop nvidia-driver
        Restart=on-failure
        RestartSec=300

        [Install]
        WantedBy=multi-user.target
```

### Validating the Driver Container

You should be able to step into the driver container and run the `nvidia-smi` tool to validate the GPU has been recognized and see what CUDA version you are running.

```bash
$ # Assumes you're running the driver container via podman and named nvidia-driver as above...
$ podman exec -it nvidia-driver sh
sh-5.2# nvidia-smi
Tue Jun 11 19:55:25 2024
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 550.90.07              Driver Version: 550.90.07      CUDA Version: 12.4     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  Tesla M60                      On  |   00000000:00:1E.0 Off |                    0 |
| N/A   47C    P0             46W /  150W |    7131MiB /   7680MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI        PID   Type   Process name                              GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+
```

### Install Container Runtime / Toolkit

To run a CUDA container that leverages the NVIDIA driver container you now have running, install the separate NVIDIA container runtime and register it with your container runtime system (e.g. docker) following NVIDIA's instructions [here](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

On FedoraCoreOS you may choose to layer the container toolkit using `rpm-ostree`, and configure your runtime, with an ignition snippet like this (substitute your runtime, containerd is shown, but docker works too for example):

```yaml
variant: fcos
version: 1.5.0
storage:
  files:
    - path: /etc/nvidia-container-runtime/config.toml
      mode: 0644
      contents:
        inline: |
          [nvidia-container-cli]
          #debug = "/var/log/nvidia-container-toolkit.log"
          root = "/run/nvidia/driver"
          path = "/usr/bin/nvidia-container-cli"
    # Improvements made in NVIDIA container toolkit 1.15.0 do not yet seem to correctly
    # support FCOS so we still need to explicitly add the driver path to ld.so.conf
    - path: /etc/ld.so.conf.d/container-toolkit.conf
      mode: 0644
      contents:
        inline: |
          /run/nvidia/driver/usr/lib64
systemd:
  units:
    - name: acme-layer-nvidia-container-toolkit.service
      enabled: true
      # We run before `zincati.service` to avoid conflicting rpm-ostree transactions.
      contents: |
        [Unit]
        Wants=network-online.target
        After=network-online.target
        Before=zincati.service
        ConditionPathExists=!/var/lib/%N.stamp
        StartLimitInterval=350
        StartLimitBurst=5
        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStartPre=-/bin/rm -rf /var/cache/rpm-ostree/repomd/{libnvidia,nvidia}*
        ExecStartPre=-/bin/sh -c 'curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
            > /etc/yum.repos.d/nvidia-container-toolkit.repo'
        # Perhaps consider pinning the rpm version here depending on change aversion...
        ExecStart=/usr/bin/rpm-ostree install -y --idempotent --allow-inactive nvidia-container-toolkit
        ExecStart=/bin/sh -c 'if [[ -f /usr/bin/nvidia-ctk ]]; then \
              /usr/bin/nvidia-ctk runtime configure --runtime=containerd --nvidia-set-as-default; \
              systemctl restart containerd; \
              /bin/touch /var/lib/%N.stamp; fi'
        ExecStart=/bin/systemctl --no-block reboot
        Restart=on-failure
        RestartSec=60

        [Install]
        WantedBy=multi-user.target
```

### Running a CUDA Container

Finally you should be able to run a GPU workload - which you can do via docker even if you've chosen to run the driver container via podman.

```bash
$ docker run --runtime=nvidia nvidia/samples:vectoradd-cuda11.2.1
[Vector addition of 50000 elements]
Copy input data from the host memory to the CUDA device
CUDA kernel launch with 196 blocks of 256 threads
Copy output data from the CUDA device to the host memory
Test PASSED
Done
```

## License Information

View license information for the software contained in this image in the git repo.

As with all Docker images, these likely also contain other software which may be under other licenses (such as Bash, etc from the base distribution, along with any direct or indirect dependencies of the primary software being contained).

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.

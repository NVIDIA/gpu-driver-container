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
$ DRIVER_VERSION=535.104.12 # Check ci/fedora/.common-ci-fcos.yml for latest
$ FEDORA_VERSION_ID=$(cat /etc/os-release | grep VERSION_ID | cut -d = -f2)
$ podman run -d --privileged --pid=host \
     -v /run/nvidia:/run/nvidia:shared \
     -v /var/log:/var/log \
     --name nvidia-driver \
     registry.gitlab.com/container-toolkit-fcos/driver:${DRIVER_VERSION}-fedora$$FEDORA_VERSION_ID
```

Or, on FCOS registering as a systemd unit via an ignition snippet, and using an image with kernel headers pre-installed for faster start up:

```yaml
variant: fcos
version: 1.4.0
storage:
  files:
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
        ExecStartPre=-/bin/sh -c 'KERNEL_VERSION=$(/bin/uname -r);FEDORA_VERSION_ID=$(cat /etc/os-release | grep VERSION_ID | cut -d = -f2); \
            /bin/podman pull registry.gitlab.com/container-toolkit-fcos/driver:535.104.12-$$KERNEL_VERSION-fedora$$FEDORA_VERSION_ID'
        ExecStartPre=-/usr/sbin/modprobe video
        ExecStart=/bin/sh -c 'KERNEL_VERSION=$(/bin/uname -r);FEDORA_VERSION_ID=$(cat /etc/os-release | grep VERSION_ID | cut -d = -f2); \
            /bin/podman run --name nvidia-driver \
                -v /run/nvidia:/run/nvidia:shared \
                -v /var/log:/var/log \
                --privileged --pid=host \
                # No need for network IF using container image with pre-built kernel headers \
                --network=none \
                registry.gitlab.com/container-toolkit-fcos/driver:535.104.12-$$KERNEL_VERSION-fedora$$FEDORA_VERSION_ID \
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
$ podman exec -it nvidia-driver bash
[root@8dc88dad905e nvidia-510.47.03]# nvidia-smi
Wed May 25 15:24:00 2022
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 525.85.12    Driver Version: 525.85.12    CUDA Version: 12.0     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  NVIDIA A10G         On   | 00000000:00:1E.0 Off |                    0 |
|  0%   39C    P0   197W / 300W |  22022MiB / 23028MiB |     96%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
[root@8dc88dad905e]#
```

### Install Container Runtime / Toolkit

To run a CUDA container that leverages the NVIDIA driver container you now have running, install the separate NVIDIA container runtime and register it with your container runtime system (e.g. docker) following NVIDIA's instructions [here](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

On FedoraCoreOS you may choose to layer the container toolkit using `rpm-ostree`, and configure your runtime, with an ignition snippet like this (substitute your runtime, docker is shown, but containerd works too for example):

```yaml
variant: fcos
version: 1.4.0
storage:
  files:
    - name: acme-layer-nvidia-container-runtime.service
      enabled: true
      # We run before `zincati.service` to avoid conflicting rpm-ostree transactions.
      contents: |
        [Unit]
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
        ExecStart=/usr/bin/rpm-ostree install --idempotent --allow-inactive --apply-live nvidia-container-toolkit
        ExecStart=/bin/sh -c 'echo "/run/nvidia/driver/usr/lib64" > /etc/ld.so.conf.d/nv.conf; ldconfig'
        # If we see that the nvidia-ctk is present, then we can configure docker...
        ExecStart=/bin/sh -c 'if [[ -f /usr/bin/nvidia-ctk ]]; then \
              /usr/bin/nvidia-ctk runtime configure --runtime=docker --nvidia-set-as-default; \
              systemctl restart docker; \
              /bin/touch /var/lib/%N.stamp; fi'
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

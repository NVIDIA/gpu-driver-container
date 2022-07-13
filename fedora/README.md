# NVIDIA GPU Driver Container for Fedora & FedoraCoreOS

[FedoraCoreOS (FCOS)](https://getfedora.org/en/coreos?stream=stable) is a self-updating minimal container-optimized Linux distribution downstream of Fedora.

NVIDIA does not yet support FCOS and so the forked Gitlab project [here](https://gitlab.com/container-toolkit-fcos/driver.git) produces Fedora kernel-specific container images.

Since these images are built on FedoraCoreOS gitlab-runners tracking the next/development/stable streams we use the `nvidia-driver update` function to include pre-compiled kernel modules speeding driver startup.

Images are pushed first on a pre-release basis to the in-built GitLab docker registry and pushed to Dockerhub [here](https://hub.docker.com/repository/docker/fifofonix/driver) once security scanned and validated.

When run as a privileged 'driver container' they install/run NVIDIA kernel modules.

See [here](https://github.com/NVIDIA/nvidia-docker/wiki/) for an overview of the overall architecture.

Together with the separate [NVIDIA Container Runtime](https://github.com/NVIDIA/nvidia-docker) which can be installed via a Fedora-specific [fork](https://container-toolkit-fcos.gitlab.io/container-runtime) containerized GPU workloads can be run.

## Supported GPUs/Drivers

NVIDIA datacenter GPUs based on Pascal+ architecture (e.g. P100, V100, T4, A100) running x86 FCOS are supported.

NVIDIA datacenter drivers support a specific CUDA version and have minimum supported Linux kernel constraints.

Currently built driver version are specified in `ci/fedora/.common-ci-fcos.yml` with 510.47.03 the latest target.

## Getting Started

### Running the Driver Container

The driver container is privileged, and here we choose to launch via podman instead of docker.

```bash
$ DRIVER_VERSION=510.47.03-fedora$(cat /etc/os-release | grep VERSION_ID | cut -d = -f2)-$(uname -r)
$ podman run -d --privileged --pid=host \
     -v /run/nvidia:/run/nvidia:shared \
     -v /tmp/nvidia:/var/log \
     --name nvidia-driver \
     registry.gitlab.com/container-toolkit-fcos/driver:${DRIVER_VERSION}
```

Or, on FCOS registering as a systemd unit via an ignition snippet.

```
...
    - name: acme-nvidia-driver.service
      enabled: true
      contents: |
        [Unit]
        Requires=network-online.target
        After=network-online.target

        [Service]
        TimeoutStartSec=250
        ExecStartPre=-/bin/podman stop nvidia-driver
        ExecStartPre=-/bin/podman rm nvidia-driver

        # Switch off SELINUX enforcement...interested in knowing how to avoid requiring this...
        ExecStartPre=-setenforce 0
        ExecStartPre=-/bin/mkdir -p /run/nvidia
        ExecStartPre=-/bin/sh -c 'KERNEL_VERSION=$(/bin/uname -r);FEDORA_VERSION_ID=$(cat /etc/os-release | grep VERSION_ID | cut -d = -f2); \
            /bin/podman pull registry.gitlab.com/container-toolkit-fcos/driver:510.47.03-$$FEDORA_VERSION_ID-$$KERNEL_VERSION'
        ExecStart=/bin/sh -c 'KERNEL_VERSION=$(/bin/uname -r);FEDORA_VERSION_ID=$(cat /etc/os-release | grep VERSION_ID | cut -d = -f2);/bin/podman run --name nvidia-driver \
            -v /run/nvidia:/run/nvidia:shared \
            -v /var/log:/var/log \
            --privileged \
            --pid=host \
            registry.gitlab.com/container-toolkit-fcos/driver:510.47.03-fedora$$FEDORA_VERSION_ID-$$KERNEL_VERSION \
                        --accept-license'

        ExecStop=/bin/podman stop nvidia-driver
        Restart=on-failure
        RestartSec=300

        [Install]
        WantedBy=multi-user.target
...
```

### Validating the Driver Container

You should be able to step into the driver container and run the `nvidia-smi` tool to validate the GPU has been recognized and see what CUDA version you are running.

```bash
$ # Assumes you've named the container nvidia-driver as above../
$ podman exec -it nvidia-driver bash 
[root@8dc88dad905e nvidia-510.47.03]# nvidia-smi
Wed May 25 15:24:00 2022
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 510.47.03    Driver Version: 510.47.03    CUDA Version: 11.6     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  Tesla M60           On   | 00000000:00:1E.0 Off |                    0 |
| N/A   52C    P0   119W / 150W |   7313MiB /  7680MiB |    100%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
[root@8dc88dad905e nvidia-510.47.03]#
```

### Install Container Runtime / Toolkit

To run a CUDA container that leverages the NVIDIA driver container you now have running, install the separate NVIDIA container runtime and register it with your container runtime system (e.g. docker).

NVIDIA do not support Fedora artifacts for the container runtime but this Fedora-specific [fork](https://container-toolkit-fcos.gitlab.io/container-runtime) of the NVIDIA Container Runtime project does.

Installation instructions include a potential FCOS ignition snippet for applying changes to `/etc/docker/daemon.json` to register the runtime with docker.

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

# License Information

View license information for the software contained in this image in the git repo.

As with all Docker images, these likely also contain other software which may be under other licenses (such as Bash, etc from the base distribution, along with any direct or indirect dependencies of the primary software being contained).

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.
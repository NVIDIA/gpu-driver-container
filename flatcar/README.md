# NVIDIA Drivers and Flatcar Container Linux

[Flatcar Container Linux](https://kinvolk.io/flatcar-container-linux/) is a Linux distribution designed for container workloads. 
To provide better security, Flatcar is immutable and contains minimal tools to run container workloads. This repository contains code to be able to build and provision NVIDIA drivers for Flatcar Linux through the use of containers. The NVIDIA driver container takes care of building the NVIDIA kernel modules and optionally loading them for running CUDA workloads. Together with the [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-docker), also provisioned using a container, you can start running GPU accelerated containers on Flatcar Linux. 

## Prerequisites

Since the driver container uses a `loop` device to mount the Flatcar development environment, the `loop` kernel module should be loaded. 
The NVIDIA driver also has a dependency on the following modules: `i2c_core` and `ipmi_msghandler`. For convenience, these modules can be 
configured to be loaded at reboot.

```bash
$ sudo modprobe -a loop i2c_core ipmi_msghandler \
    && echo -e "loop\ni2c_core\nipmi_msghandler" | sudo tee /etc/modules-load.d/driver.conf
```

If you're getting started with Flatcar on EC2, then Flatcar images for various regions can be found here:
https://kinvolk.io/docs/flatcar-container-linux/latest/installing/cloud/aws-ec2/

## Supported Drivers

Only the following NVIDIA datacenter drivers are supported on Linux kernels 5.9+:
1. [`450.102.04`](https://www.nvidia.com/Download/driverResults.aspx/169393/en-us)
1. [`460.32.03`](https://www.nvidia.com/Download/driverResults.aspx/169408/en-us)

NVIDIA datacenter GPUs based on Pascal+ architecture (e.g. P100, V100, T4, A100) are supported. Note that NVSwitch based systems (e.g. 
HGX-2 or HGX A100) are not yet supported.

## Getting Started

Setup the NVIDIA Container Toolkit using the [container-config](https://gitlab.com/nvidia/container-toolkit/container-config) project:
```bash
$ docker run --rm --privileged \
     -v "/etc/docker:/etc/docker" \
     -v "/run/nvidia:/run/nvidia" \
     -v "/run/docker.sock:/run/docker.sock" \
     -v "/opt/nvidia-runtime:/opt/nvidia-runtime" \
     -e "RUNTIME=docker" \
     -e "RUNTIME_ARGS=--socket /run/docker.sock" \
     -e "DOCKER_SOCKET=/run/docker.sock" \
     nvcr.io/nvidia/k8s/container-toolkit:1.4.7-ubuntu18.04 \
     "/opt/nvidia-runtime"
```
You should see an output as shown below:
```console
time="2021-04-06T06:54:23Z" level=info msg="Setting up runtime"
time="2021-04-06T06:54:23Z" level=info msg="Starting 'setup' for docker"
time="2021-04-06T06:54:23Z" level=info msg="Parsing arguments: [/opt/nvidia-runtime/toolkit]"
time="2021-04-06T06:54:23Z" level=info msg="Successfully parsed arguments"
time="2021-04-06T06:54:23Z" level=info msg="Loading config: /etc/docker/daemon.json"
time="2021-04-06T06:54:23Z" level=info msg="Config file does not exist, creating new one"
time="2021-04-06T06:54:23Z" level=info msg="Flushing config"
time="2021-04-06T06:54:23Z" level=info msg="Successfully flushed config"
time="2021-04-06T06:54:23Z" level=info msg="Sending SIGHUP signal to docker"
time="2021-04-06T06:54:23Z" level=info msg="Signal received, exiting early"
time="2021-04-06T06:54:23Z" level=info msg="Shutting Down"
```

Restart `docker` to ensure that `nvidia` is added as a custom runtime:
```bash
$ sudo systemctl restart docker
$ docker info | grep -i nvidia
 Runtimes: nvidia runc
 Default Runtime: nvidia
```

The `container-config` would have also created a `daemon.json` for Docker in `/etc/docker/daemon.json` with the `nvidia` runtime binaries being located in the directory specified (`/opt/nvidia-runtime` in our example).

## Workflow

The driver container includes logic to precompile the NVIDIA kernel module interfaces and package them for later use. This has a 
few advantages - reduced startup time since the module interfaces are already built; ability to build on systems without GPUs and 
reduced image footprint as we no longer need to either download or ship the development environment within the image. 
Note that the precompilation logic works when there is a matching running kernel and falls back to building the modules. 

To facilitate this optimization, the workflow can be:
1. Build the driver container
1. Commit and tag the image with a changed entrypoint
1. Run the driver container with the tagged image in the previous step

Note that you can skip these steps on systems where you want to build and run the container directly by providing 
the `init` argument to the driver container (instead of `update`) in the workflow below. By doing so, the driver 
container will first build and then load the kernel modules.

### Building the Driver Container

Clone this repository and build a driver container image using the following as an example:

```bash
$ git clone https://gitlab.com/nvidia/container-images/driver.git \
    && cd driver/flatcar
```

```bash
$ DRIVER_VERSION=460.32.03 
$ docker build --pull \
    --tag nvidia/nvidia-driver-flatcar:${DRIVER_VERSION} \
    --file Dockerfile .
```

### Precompile Kernel Interfaces

Launch the driver container using the following as an example:

```bash
$ docker run -d --privileged --pid=host \
    -v /run/nvidia:/run/nvidia:shared \
    -v /tmp/nvidia:/var/log \
    -v /usr/lib64/modules:/usr/lib64/modules \
    --name nvidia-driver \
    nvidia/nvidia-driver-flatcar:${DRIVER_VERSION} update
```

The building of the kernel modules takes a few minutes. You can also stream the logs of the container:

```bash
$ docker logs -f nvidia-driver
```
Once the modules are built, you should see an output as shown:

```console
Compiling NVIDIA driver kernel modules with gcc (Gentoo Hardened 9.3.0-r1 p3) 9.3.0...
scripts/Makefile.lib:8: 'always' is deprecated. Please use 'always-y' instead
Cleaning up the development environment...
Checking NVIDIA driver packages...
Building NVIDIA driver package nvidia-modules-5.10.25...
Packaged precompiled driver into /usr/src/nvidia-460.32.03/kernel/precompiled/5.10.25-flatcar
Done
```

### Commit Image

Now we can commit the image with a changed entrypoint. The image may also be stored in an image registry for use later.

```bash
$ docker commit \
    --change='ENTRYPOINT ["nvidia-driver", "init"]' \
    nvidia-driver nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}
```

### Running the Driver Container

Run the driver container with the tagged image from the previous step:

```bash
$ docker run -d --privileged --pid=host \
     -v /run/nvidia:/run/nvidia:shared \
     -v /tmp/nvidia:/var/log \
     -v /usr/lib64/modules:/usr/lib64/modules \
     nvidia/nvidia-kmods-driver-flatcar:${DRIVER_VERSION}
```

The driver container will look for the precompiled interfaces and then use those if available. 
The startup time of the container in this case would be reduced:

```console
...
========== NVIDIA Software Installer ==========
Starting installation of NVIDIA driver version 460.32.03 for Linux kernel version 5.10.25-flatcar
Stopping NVIDIA persistence daemon...
Unloading NVIDIA driver kernel modules...
Unmounting NVIDIA driver rootfs...
Checking NVIDIA driver packages...
Found NVIDIA driver package nvidia-modules-5.10.25
Installing NVIDIA driver kernel modules...
Re-linking NVIDIA driver kernel modules...
depmod: WARNING: could not open /opt/nvidia/460.32.03/lib/modules/5.10.25-flatcar/modules.builtin: No such file or directory
Loading NVIDIA driver kernel modules...
Starting NVIDIA persistence daemon...
Mounting NVIDIA driver rootfs...
Done, now waiting for signal
```

You can also verify that the NVIDIA kernel modules are loaded in the system:

```bash
$ lsmod | grep -i nvidia
nvidia_modeset       1228800  0
nvidia_uvm           1130496  0
nvidia              34078720  17 nvidia_uvm,nvidia_modeset
i2c_core               81920  3 nvidia,psmouse,i2c_piix4
```

## Sample CUDA Workloads

Now we can run some sample CUDA workloads. 

1. Run `nvidia-smi`
    ```bash
    $ docker run --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi
    
    +-----------------------------------------------------------------------------+
    | NVIDIA-SMI 460.32.03    Driver Version: 460.32.03    CUDA Version: 11.2     |
    |-------------------------------+----------------------+----------------------+
    | GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
    | Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
    |                               |                      |               MIG M. |
    |===============================+======================+======================|
    |   0  Tesla T4            On   | 00000000:00:1E.0 Off |                    0 |
    | N/A   30C    P8     9W /  70W |      0MiB / 15109MiB |      0%      Default |
    |                               |                      |                  N/A |
    +-------------------------------+----------------------+----------------------+
    
    +-----------------------------------------------------------------------------+
    | Processes:                                                                  |
    |  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
    |        ID   ID                                                   Usage      |
    |=============================================================================|
    |  No running processes found                                                 |
    +-----------------------------------------------------------------------------+        
    ```

1. Run a sample CUDA program:
    ```bash
    $ docker run --runtime=nvidia nvidia/samples:vectoradd-cuda11.2.1

    [Vector addition of 50000 elements]
    Copy input data from the host memory to the CUDA device
    CUDA kernel launch with 196 blocks of 256 threads
    Copy output data from the CUDA device to the host memory
    Test PASSED
    Done    
    ```

1. Generate a deterministic FP16 GEMM on the GPU using the Tensor Cores if available:
    ```bash
    $ docker run --runtime=nvidia \
        --cap-add SYS_ADMIN \
        nvidia/samples:dcgmproftester-2.0.10-cuda11.0-ubuntu18.04 \
        --no-dcgm-validation -t 1004 -d 30

    Skipping CreateDcgmGroups() since DCGM validation is disabled
    CU_DEVICE_ATTRIBUTE_MAX_THREADS_PER_MULTIPROCESSOR: 1024
    CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT: 40
    CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_MULTIPROCESSOR: 65536
    CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR: 7
    CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR: 5
    CU_DEVICE_ATTRIBUTE_GLOBAL_MEMORY_BUS_WIDTH: 256
    CU_DEVICE_ATTRIBUTE_MEMORY_CLOCK_RATE: 5001000
    Max Memory bandwidth: 320064000000 bytes (320.06 GiB)
    CudaInit completed successfully.
    
    Skipping WatchFields() since DCGM validation is disabled
    TensorEngineActive: generated ???, dcgm 0.000 (26723.0 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27450.3 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27520.2 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27386.5 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27294.1 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27304.2 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27220.1 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27193.2 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27139.5 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27125.2 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (26985.2 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27282.3 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27413.9 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27366.0 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27378.1 gflops)
    TensorEngineActive: generated ???, dcgm 0.000 (27244.6 gflops)    
        ```
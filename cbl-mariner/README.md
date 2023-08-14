# CBL-Mariner (EXPERIMENTAL)

This directory containers the docker manifests used to run the precompiled gpu driver on Azure Linux/CBL-Mariner Linux,
the fedora based Linux distribution provided by Microsoft

The container essentially pulls the driver rpm packages hosted here: https://packages.microsoft.com/cbl-mariner/2.0/prod/nvidia/x86_64/Packages/ 

The following driver versions are supported:

- 515.65.01
- 525.85.12

## Running the container

1. Set the necessary environment variables
   1. export DRIVER_VERSION=525.85.12
   2. KERNEL_VERSION=5.15.118.1-1.cm2

2. Run the docker build with the following command:
   ```
   docker build \
   --build-arg DRIVER_VERSION="${DRIVER_VERSION}"  \
   --build-arg KERNEL_VERSION="${KERNEL_VERSION}" \
   -t <image-name-with-tag>
   ```

3. Once the docker is built successfully, you can issue the docker run command
    ```
   docker run --name nvidia-driver -d --privileged --pid=host -v /run/nvidia:/run/nvidia:shared -v /var/log:/var/log -v /etc/os-release:/host-etc/os-release -v /dev/log:/dev/log <image-name-with-tag>
   ```

**NOTE**: This image is experimental and is still under evaluation. We do not recommend using this for any workloads other than for
testing/development purposes.

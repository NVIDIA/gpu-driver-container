# Fedora [![build status](https://gitlab.com/nvidia/driver/badges/master/build.svg)](https://gitlab.com/nvidia/driver/commits/master)

See <https://github.com/NVIDIA/nvidia-docker/wiki/Driver-containers-(Beta>)

Building and running locally:

```
DRIVER_VERSION=450.51.05
FEDORA_VERSION=32
sudo podman build \
    --build-arg FEDORA_VERSION=$FEDORA_VERSION \
    --build-arg DRIVER_VERSION=$DRIVER_VERSION \
    -t docker.io/nvidia/driver:$DRIVER_VERSION-fedora$FEDORA_VERSION .
sudo podman run --name nvidia-driver --privileged --pid=host \
    -v /run/nvidia:/run/nvidia:shared \
    docker.io/nvidia/driver:$DRIVER_VERSION-fedora$FEDORA_VERSION \
    --accept-license
```

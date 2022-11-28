## Build

```
docker build -t mydriver \
    --build-arg DRIVER_VERSION="510.85.02" \
    --build-arg CUDA_VERSION="11.7.1" \
    --build-arg SLES_VERSION="15.3" \
    .
```

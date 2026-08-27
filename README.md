# GPU Driver Container

[![build status](https://gitlab.com/nvidia/container-images/driver/badges/master/pipeline.svg)](https://gitlab.com/nvidia/container-images/driver/-/commits/master)

The NVIDIA GPU driver container allows the provisioning of the NVIDIA driver through the use of containers.

## Documentation

[Driver Container documentation](https://docs.nvidia.com/datacenter/cloud-native/driver-containers/overview.html)

## Releases

[NVIDIA GPU Driver at NGC](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/driver)

## Building from Source

```sh
platform=ubuntu22.04 # where ${platform} is one of the supported platforms (e.g. ubuntu22.04)
docker build -t mydriver --build-arg DRIVER_VERSION="510.85.02" --build-arg CUDA_VERSION=11.7.1 --build-arg TARGETARCH=amd64 ${platform}
```

## License

[Apache License 2.0](LICENSE)
[License For Customer Use of NVIDIA Software](https://www.nvidia.com/content/DriverDownload-March2009/licence.php?lang=us)

## Contributions
[Read the document on contributions](CONTRIBUTING.md). 
You can contribute by opening a [pull request](https://help.github.com/en/articles/about-pull-requests).
Contributions must adhere to the [Code of Conduct](CODE_OF_CONDUCT.md).

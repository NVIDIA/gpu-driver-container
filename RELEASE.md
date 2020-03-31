# RELEASE and Versioning

## Versioning

The driver container posses four major components:
- The version of the driver that will be installed on your host (e.g: 440.33.01).
- The version of the script installing and managing the driver container (e.g: 1.0.0).
- The version of the linux kernel the driver has been pre-compiled against (e.g: 4.4.0-1098)
- The platform this container is intended to run on (e.g: ubuntu18.04-aws, rhcos4.4, ...)

The overall version of the driver container has two forms:
- The long form: `${DRIVER_VERSION}-${CONTAINER_VERSION}-${LINUX_VERSION}-${PLATFORM}`
- The short form: `${DRIVER_VERSION}-${PLATFORM}`

The long form is a unique tag that once pushed will always refer to the same container.
This means that no updates will be made to that tag and it will always point to the same container.

The short form refers to the latest CONTAINER_VERSION and LINUX_VERSION. This means that whenever a new
linux version is published or a new container version is published, this tag will be updated.
In practice the Linux version is usually updated once a month.

We do not maintain multiple branches, which means that when we release a driver container, we only release
one with the latest of all components.
To clarify what this means with respect to the Linux version, this means that when a new Driver is released
or a new version of the container is released, we do not generate containers for previous linux versions.

## Continuous Release

The Driver Container CI is automatically triggered once per day and will check for a new update of the
linux kernel for each supported distribution.

If it finds a new version, a new driver container will be built and pushed to the official NVIDIA dockerhub.

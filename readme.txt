docker run --rm --privileged multiarch/qemu-user-static --reset --persistent yes

docker buildx build --platform linux/aarch64 --load --build-arg ALPINE_VERSION=3.12 --build-arg GLIBC_VERSION=2.32 --build-arg GLIBC_RELEASE=0 --build-arg MAINTAINER=devops.spectx.com --progress plain .


---
based on work by @sgerrand and @frezbo
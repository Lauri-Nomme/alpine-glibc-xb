docker run --rm --privileged multiarch/qemu-user-static --reset --persistent yes

docker buildx build --platform linux/aarch64 \
    --build-arg ALPINE_VERSION=3.12 \
    --build-arg GLIBC_VERSION=2.32 \
    --build-arg GLIBC_RELEASE=0 \
    --build-arg MAINTAINER=devops.spectx.com \
    --build-arg "PRIVKEY=$(cat devops.spectx.com-key.pem)" \
    --tag glibc:out
    --load \
    .

docker run -v $(realpath out):/out --rm --entrypoint sh glibc:out -c "cp -r /packages/*.pub /packages/*/*/* /out/"
docker image rm glibc:out

~/go/bin/ghr -u lauri-nomme -r alpine-glibc-xb aarch64-2.32 out/

---
based on work by @sgerrand and @frezbo
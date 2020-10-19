ARG ENVIRONMENT

ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS glibc-base
ARG GLIBC_VERSION
ARG GLIBC_URL=https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz
ARG CHECKSUM=881ca905e6b5eec724de7948f14d66a07d97bdee8013e1b2a7d021ff5d540522
ARG GLIBC_ASC_URL=https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz.sig
ARG GPG_KEY_URL=https://ftp.gnu.org/gnu/gnu-keyring.gpg
RUN apk add --no-cache curl gnupg && \
    curl -sSL ${GLIBC_URL} -o $(basename ${GLIBC_URL}) && \
#    curl -o $(basename ${GLIBC_ASC_URL}) ${GLIBC_ASC_URL} && \
#    curl -fsSL ${GPG_KEY_URL} | gpg --import && \
#    gpg --batch --verify $(basename ${GLIBC_ASC_URL}) $(basename ${GLIBC_URL}) && \
#    echo "${CHECKSUM}  $(basename ${GLIBC_URL})" | sha256sum -c && \
    tar xzf $(basename ${GLIBC_URL})

FROM ubuntu:20.04 as glibc-compiler
ARG GLIBC_VERSION
ARG GLIBC_RELEASE
ARG PREFIX_DIR=/usr/glibc-compat
RUN apt-get update && \
    apt-get install -y build-essential openssl gawk bison python3
COPY --from=glibc-base /glibc-${GLIBC_VERSION} /glibc/
COPY ld.so.conf ${PREFIX_DIR}/etc/
WORKDIR /glibc-build
RUN /glibc/configure \
    --prefix=${PREFIX_DIR} \
    --libdir=${PREFIX_DIR}/lib \
    --libexecdir=${PREFIX_DIR}/lib \
    --enable-multi-arch \
    --enable-stack-protector=strong && \
    make && \
    make install && \
    tar --hard-dereference -zcf /glibc-bin-${GLIBC_VERSION}.tar.gz ${PREFIX_DIR} && \
    sha512sum /glibc-bin-${GLIBC_VERSION}.tar.gz > /glibc-bin-${GLIBC_VERSION}.sha512sum

FROM alpine:${ALPINE_VERSION} AS glibc-alpine-builder
ARG MAINTAINER
ARG GLIBC_VERSION
ARG GLIBC_RELEASE
RUN apk --no-cache add alpine-sdk coreutils cmake libc6-compat && \
    adduser -G abuild -g "Alpine Package Builder" -s /bin/ash -D builder && \
    echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir /packages && \
    chown builder:abuild /packages
USER builder
RUN mkdir /home/builder/package/
WORKDIR /home/builder/package/
COPY --from=glibc-compiler /glibc-bin-${GLIBC_VERSION}.tar.gz .
COPY --from=glibc-compiler /glibc-bin-${GLIBC_VERSION}.sha512sum .
COPY APKBUILD .
COPY glibc-bin.trigger .
COPY ld.so.conf .
COPY nsswitch.conf .
ENV REPODEST /packages
ENV ABUILD_KEY_DIR /home/builder/.abuild
RUN mkdir -p ${ABUILD_KEY_DIR} && \
    openssl genrsa -out ${ABUILD_KEY_DIR}/${MAINTAINER}-key.pem 2048 && \
    sudo openssl rsa -in ${ABUILD_KEY_DIR}/${MAINTAINER}-key.pem -pubout -out /etc/apk/keys/${MAINTAINER}.rsa.pub && \
    echo "PACKAGER_PRIVKEY=\"${ABUILD_KEY_DIR}/${MAINTAINER}-key.pem\"" > ${ABUILD_KEY_DIR}/abuild.conf && \
    sed -i "s/<\${GLIBC_VERSION}-checksum>/$(cat glibc-bin-${GLIBC_VERSION}.sha512sum | awk '{print $1}')/" APKBUILD && \
    abuild -r

#FROM alpine:${ALPINE_VERSION}
#ARG GLIBC_VERSION
#ARG GLIBC_RELEASE
#ARG BUILD_DATE
#ARG GIT_SHA
#ARG GIT_TAG
#COPY --from=glibc-alpine-builder /packages/builder/x86_64/glibc-${GLIBC_VERSION}-${GLIBC_RELEASE}.apk /tmp/
#COPY --from=glibc-alpine-builder /packages/builder/x86_64/glibc-bin-${GLIBC_VERSION}-${GLIBC_RELEASE}.apk /tmp/
#COPY --from=glibc-alpine-builder /packages/builder/x86_64/glibc-i18n-${GLIBC_VERSION}-${GLIBC_RELEASE}.apk /tmp/
#RUN apk upgrade --no-cache && \
#    apk add --no-cache libstdc++ curl && \
#    apk add --allow-untrusted /tmp/*.apk && \
#    ( /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 C.UTF-8 || true ) && \
#    echo "export LANG=C.UTF-8" > /etc/profile.d/locale.sh && \
#    /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib

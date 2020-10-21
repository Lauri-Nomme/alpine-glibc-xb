ARG ENVIRONMENT

ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS glibc-base
ARG GLIBC_VERSION
ARG GLIBC_URL=https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz
ARG CHECKSUM=
ARG GLIBC_ASC_URL=https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz.sig
ARG GPG_KEY_URL=https://ftp.gnu.org/gnu/gnu-keyring.gpg
RUN apk add --no-cache curl gnupg && \
    curl -sSL ${GLIBC_URL} -o $(basename ${GLIBC_URL}) && \
# fails due to expired keys
#    curl -o $(basename ${GLIBC_ASC_URL}) ${GLIBC_ASC_URL} && \
#    curl -fsSL ${GPG_KEY_URL} | gpg --import && \
#    gpg --batch --verify $(basename ${GLIBC_ASC_URL}) $(basename ${GLIBC_URL}) && \
    [[ -z "${CHECKSUM}" ]] || (echo "${CHECKSUM}  $(basename ${GLIBC_URL})" | sha256sum -c) && \
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
ARG PRIVKEY
ARG GLIBC_VERSION
ARG GLIBC_RELEASE
ARG TARGETARCH
RUN apk --no-cache add alpine-sdk coreutils cmake libc6-compat build-base && \
    adduser -G abuild -g "Alpine Package Builder" -s /bin/ash -D builder && \
    mkdir /packages && \
    chown builder:abuild /packages && \
	chown -R builder:abuild /etc/apk/keys
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
	(([[ -n "${PRIVKEY}" ]] && echo "using passed key" && echo "$PRIVKEY" > ${ABUILD_KEY_DIR}/${MAINTAINER}.rsa) || \
    openssl genrsa -out ${ABUILD_KEY_DIR}/${MAINTAINER}.rsa 2048) && \
    openssl rsa -in ${ABUILD_KEY_DIR}/${MAINTAINER}.rsa -pubout -out /etc/apk/keys/${MAINTAINER}.rsa.pub && \
    echo "PACKAGER_PRIVKEY=\"${ABUILD_KEY_DIR}/${MAINTAINER}.rsa\"" > ${ABUILD_KEY_DIR}/abuild.conf && \
    sed -i "s/<\${GLIBC_VERSION}-checksum>/$(cat glibc-bin-${GLIBC_VERSION}.sha512sum | awk '{print $1}')/" APKBUILD && \
	export TARGETARCH=$(echo $TARGETARCH | sed -e's/arm64/aarch64/' ) && \
	echo TARGETARCH=$TARGETARCH && \
    abuild && \
	cp /etc/apk/keys/${MAINTAINER}.rsa.pub $REPODEST/ && \
	ls -latrR $REPODEST/

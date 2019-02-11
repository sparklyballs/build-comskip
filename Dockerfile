ARG UBUNTU_VER="bionic"
FROM ubuntu:${UBUNTU_VER} as fetch-stage

############## fetch stage ##############

# set environment variables
ARG DEBIAN_FRONTEND="noninteractive"

# install fetch packages
RUN \
	set -ex \
	&& apt-get update \
	&& apt-get install -y \
	--no-install-recommends \
		ca-certificates \
		curl \
	\
# cleanup
	\
	&& rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/*

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# fetch source code
RUN \
	set -ex \
	&& mkdir -p \ 
		/tmp/comskip-src \
		/tmp/ffmpeg-src \
	&& COMSKIP_COMMIT=$(curl -sX GET "https://api.github.com/repos/erikkaashoek/Comskip/commits/master" \
		| awk '/sha/{print $4;exit}' FS='[""]'| head -c7) || : \
	&& FFMPEG_COMMIT=$(curl -sX GET "https://api.github.com/repos/FFmpeg/FFmpeg/commits/master" \
		| awk '/sha/{print $4;exit}' FS='[""]'| head -c7) || : \
	&& curl -o \
	/tmp/comskip.tar.gz -L \
	"https://github.com/erikkaashoek/Comskip/archive/${COMSKIP_COMMIT}.tar.gz" \
	&& curl -o \
	/tmp/ffmpeg.tar.gz -L \
	"https://github.com/FFmpeg/FFmpeg/archive/${FFMPEG_COMMIT}.tar.gz" \
	&& tar xf \
	/tmp/comskip.tar.gz -C \
	/tmp/comskip-src --strip-components=1 \
	&& tar xf \
	/tmp/ffmpeg.tar.gz -C \
	/tmp/ffmpeg-src --strip-components=1 \
	&& echo "COMSKIP_COMMIT=${COMSKIP_COMMIT}" > /tmp/version.txt \
	&& echo "FFMPEG_COMMIT=${FFMPEG_COMMIT}" >> /tmp/version.txt

FROM ubuntu:${UBUNTU_VER} as ffmpeg-build-stage

############## ffmpeg build stage ##############

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"

# install build packages
RUN \
	set -ex \
	&& apt-get update \
	&& apt-get install -y \
	--no-install-recommends \
		g++ \
		gcc \
		libtool \
		make \
		pkg-config \
		xz-utils \
		yasm \
	\
# cleanup
	\
	&& rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/*

# copy artifacts from fetch stage
COPY --from=fetch-stage /tmp/ffmpeg-src /tmp/ffmpeg-src

# set workdir
WORKDIR /tmp/ffmpeg-src

# build package
RUN \
	set -ex \
	&& ./configure \
		--disable-programs \
		--prefix=/tmp/ffmpeg-build/install \
	&& make \
	&& make install

FROM ubuntu:${UBUNTU_VER} as comskip-build-stage

############## comskip build stage ##############

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"

# install build packages
RUN \
	set -ex \
	&& apt-get update \
	&& apt-get install -y \
	--no-install-recommends \
		autoconf \
		automake \
		g++ \
		gcc \
		libargtable2-dev \
		libtool \
		make \
		pkg-config \
		xz-utils \
		yasm \
	\
# cleanup
	\
	&& rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/*

# copy artifacts from fetch amd ffmpeg build stages
COPY --from=fetch-stage /tmp/comskip-src /tmp/comskip-src
COPY --from=ffmpeg-build-stage /tmp/ffmpeg-build /tmp/ffmpeg-build

# set workdir
WORKDIR /tmp/comskip-src

# build package
RUN \
	set -ex \
	&& ./autogen.sh \
	&& PKG_CONFIG_PATH=/tmp/ffmpeg-build/install/lib/pkgconfig ./configure \
		--bindir=/tmp/comskip-build \
		--enable-static \
	&& make \
	&& make install

FROM ubuntu:${UBUNTU_VER}

############## package stage ##############

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"

# install strip packages
RUN \
	set -ex \
	&& apt-get update \
	&& apt-get install -y \
	--no-install-recommends \
		binutils \
	\
# cleanup
	\
	&& rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/*

# copy fetch and build artifacts
COPY --from=comskip-build-stage /tmp/comskip-build /tmp/comskip-build
COPY --from=fetch-stage /tmp/version.txt /tmp/version.txt

# set workdir
WORKDIR /tmp/comskip-build

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# strip and archive package
# hadolint ignore=SC1091
RUN \
	source /tmp/version.txt \
	&& set -ex \
	&& mkdir -p \
		/build \
	&& strip --strip-all comskip \
	&& tar -czvf /build/ffmpeg-"${FFMPEG_COMMIT}"-comskip-"${COMSKIP_COMMIT}".tar.gz comskip

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]

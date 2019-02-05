ARG UBUNTU_VER="bionic"
FROM ubuntu:${UBUNTU_VER} as fetch-stage

# set environment variables
ARG DEBIAN_FRONTEND="noninteractive"

# install fetch packages
RUN \
	apt-get update \
	&& apt-get install -y \
		curl

# fetch comskip source code
RUN \
	set -ex \
	&& mkdir -p \ 
		/tmp/comskip-src \
	&& COMSKIP_COMMIT=$(curl -sX GET "https://api.github.com/repos/erikkaashoek/Comskip/commits/master" \
		| awk '/sha/{print $4;exit}' FS='[""]'| head -c7) \
	&& curl -o \
	/tmp/comskip.tar.gz -L \
	"https://github.com/erikkaashoek/Comskip/archive/${COMSKIP_COMMIT}.tar.gz" \
	&& tar xf \
	/tmp/comskip.tar.gz -C \
	/tmp/comskip-src --strip-components=1 \
	&& echo "COMSKIP_COMMIT=${COMSKIP_COMMIT}" > /tmp/version.txt

# fetch ffmpeg source code
RUN \
	set -ex \
	&& mkdir -p \ 
		/tmp/ffmpeg-src \
	&& FFMPEG_COMMIT=$(curl -sX GET "https://api.github.com/repos/FFmpeg/FFmpeg/commits/master" \
		| awk '/sha/{print $4;exit}' FS='[""]'| head -c7) \
	&& curl -o \
	/tmp/ffmpeg.tar.gz -L \
	"https://github.com/FFmpeg/FFmpeg/archive/${FFMPEG_COMMIT}.tar.gz" \
	&& tar xf \
	/tmp/ffmpeg.tar.gz -C \
	/tmp/ffmpeg-src --strip-components=1 \
	&& echo "FFMPEG_COMMIT=${FFMPEG_COMMIT}" >> /tmp/version.txt

FROM ubuntu:${UBUNTU_VER}

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"

# add fetch stage artifacts
COPY --from=fetch-stage /tmp/version.txt /tmp/version.txt
COPY --from=fetch-stage /tmp/ffmpeg-src /tmp/ffmpeg-src
COPY --from=fetch-stage /tmp/comskip-src /tmp/comskip-src

# install build packages
RUN \
	apt-get update \
	&& apt-get install -y \
		autoconf \
		automake \
		build-essential \
		bzip2 \
		libargtable2-dev \
		libtool \
		pkg-config \
		xz-utils \
		yasm

# build ffmpeg
RUN \
	set -ex \
	&& cd /tmp/ffmpeg-src \
	&& ./configure \
		--disable-programs \
		--prefix=/tmp/ffmpeg-build/install \
	&& make \
	&& make install

# build and archive package
RUN \
	set -ex \
	&& . /tmp/version.txt \
	&& mkdir -p \
		/build \
	&& cd /tmp/comskip-src \
	&& ./autogen.sh \
	&& PKG_CONFIG_PATH=/tmp/ffmpeg-build/install/lib/pkgconfig ./configure \
		--bindir=/tmp/comskip-build \
		--enable-static \
	&& make \
	&& make install \
	&& strip --strip-all /tmp/comskip-build/comskip \
	&& tar -czvf /build/ffmpeg-${FFMPEG_COMMIT}-comskip-${COMSKIP_COMMIT}.tar.gz -C /tmp/comskip-build comskip

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]

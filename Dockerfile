FROM alpine:edge as fetch-stage

# install fetch packages
RUN \
	apk add --no-cache \
		curl \
		tar 

# fetch comskip source code
RUN \
	set -ex \
	&& mkdir -p \ 
		/tmp/comskip-src \
	&& COMSKIP_COMMIT=$(curl -sX GET "https://api.github.com/repos/erikkaashoek/Comskip/commits/master" \
		| awk '/sha/{print $4;exit}' FS='[""]') \
	&& curl -o \
	/tmp/comskip.tar.gz -L \
	"https://github.com/erikkaashoek/Comskip/archive/${COMSKIP_COMMIT}.tar.gz" \
	&& tar xf \
	/tmp/comskip.tar.gz -C \
	/tmp/comskip-src --strip-components=1 \
	&& echo "COMSKIP_VERSION=${COMSKIP_COMMIT:0:7}" > /tmp/version.txt

# fetch ffmpeg source code
RUN \
	set -ex \
	&& mkdir -p \ 
		/tmp/ffmpeg-src \
	&& FFMPEG_COMMIT=$(curl -sX GET "https://api.github.com/repos/FFmpeg/FFmpeg/commits/master" \
		| awk '/sha/{print $4;exit}' FS='[""]') \
	&& curl -o \
	/tmp/ffmpeg.tar.gz -L \
	"https://github.com/FFmpeg/FFmpeg/archive/${FFMPEG_COMMIT}.tar.gz" \
	&& tar xf \
	/tmp/ffmpeg.tar.gz -C \
	/tmp/ffmpeg-src --strip-components=1 \
	&& echo "FFMPEG_VERSION=${FFMPEG_COMMIT:0:7}" >> /tmp/version.txt

FROM ubuntu:bionic

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
		--prefix=/tmp/comskipbuild/install \
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
	&& PKG_CONFIG_PATH=/tmp/comskipbuild/install/lib/pkgconfig ./configure \
		--bindir=/tmp/bin \
		--enable-static \
		--sysconfdir=/config/comskip \
	&& make \
	&& make install \
	&& strip --strip-all /tmp/bin/comskip \
	&& tar -czvf /build/ffmpeg-${FFMPEG_VERSION}-comskip-${COMSKIP_VERSION}.tar.gz -C /tmp/bin comskip

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]

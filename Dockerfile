FROM debian:stretch

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"

# install build packages
RUN \
	apt-get update \
	&& apt-get install -y \
		autoconf \
		automake \
		build-essential \
		bzip2 \
		curl \
		git \
		libargtable2-dev \
		libtool \
		pkg-config \
		xz-utils \
		yasm

# fetch source code
RUN \
	set -ex \
	&& mkdir -p \ 
		/tmp/ffmpeg-src \
	&& curl -o \
	/tmp/ffmpeg.tar.bz2 -L \
	https://www.ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2  \
	&& tar xf \
	/tmp/ffmpeg.tar.bz2 -C \
	/tmp/ffmpeg-src --strip-components=1 \
	&& git clone https://github.com/erikkaashoek/Comskip.git /tmp/comskip

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
	&& mkdir -p \
		/build \
	&& cd /tmp/comskip \
	&& ./autogen.sh \
	&& PKG_CONFIG_PATH=/tmp/comskipbuild/install/lib/pkgconfig ./configure \
		--bindir=/tmp/bin \
		--enable-static \
		--sysconfdir=/config/comskip \
	&& make \
	&& make install \
	&& strip --strip-all /tmp/bin/comskip \
	&& tar -czvf /build/comskip.tar.gz -C /tmp/bin comskip

# copy files out to /mnt
CMD ["cp", "-avr", "/build", "/mnt/"]

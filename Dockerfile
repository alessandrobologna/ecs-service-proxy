FROM        debian:jessie
MAINTAINER  alessandro.bologna@gmail.com
 
ENV DEBIAN_FRONTEND noninteractive

# Update the package repository
RUN apt-get -qq update && apt-get install -y curl apt-transport-https

# Install base system
RUN apt-get -qq update && apt-get install -y python-pip \ 
	git build-essential pkg-config libvarnish-dev libtool automake python-docutils libncurses-dev libpcre3-dev libedit-dev \
	&& curl -s -o varnish-5.0.0.tar.gz http://repo.varnish-cache.org/source/varnish-5.0.0.tar.gz \
	&& tar xvfz varnish-5.0.0.tar.gz && cd varnish-5.0.0 \
	&& ./autogen.sh && ./configure && make && make install \
	&& git clone https://github.com/aondio/libvmod-bodyaccess.git \
	&& cd libvmod-bodyaccess \
	&& ./autogen.sh && ./configure && make && make install \
	&& pip install awscli  

ADD docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod 0755 /docker-entrypoint.sh

CMD ["varnishd"]
ENTRYPOINT ["/docker-entrypoint.sh"]
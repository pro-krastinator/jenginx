FROM centos:centos7.6.1810

WORKDIR /tmp

# Install prerequisites for Nginx compile
RUN yum install -y \
        wget \
        tar \
        sudo \
        openssl-devel \
        gcc \
        gcc-c++ \
        make \
        zlib-devel \
        pcre-devel \
        gd-devel \
        krb5-devel \
        git \
        net-tools       

# Download Nginx and Nginx modules source
RUN wget http://nginx.org/download/nginx-1.17.3.tar.gz -O nginx.tar.gz && \
    mkdir /tmp/nginx && \
    tar -xzvf nginx.tar.gz -C /tmp/nginx --strip-components=1

# Build Nginx
WORKDIR /tmp/nginx
RUN ./configure \
        --user=nginx \
        --with-debug \
        --group=nginx \
        --prefix=/usr/share/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --pid-path=/run/nginx.pid \
        --lock-path=/run/lock/subsys/nginx \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --with-http_gzip_static_module \
        --with-http_stub_status_module \
        --with-http_ssl_module \
        --with-pcre \
        --with-http_image_filter_module \
        --with-file-aio \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module && \
    make && \
    make install

WORKDIR /tmp

# Add nginx user
RUN adduser -c "Nginx user" nginx && \
    setcap cap_net_bind_service=ep /usr/sbin/nginx

RUN touch /run/nginx.pid

RUN chown nginx:nginx /etc/nginx /etc/nginx/nginx.conf /var/log/nginx /usr/share/nginx /run/nginx.pid

# Cleanup after Nginx build
RUN yum remove -y  wget git \
  && yum autoremove -y && \
    rm -rf /tmp/*


# Cleanup the default NGINX configuration file we don’t need
RUN rm /etc/nginx/conf.d/default.conf || true

# Replace default port for Nginx from 80 to 8081
RUN sed -ie "s|listen\s*80;$|listen\t8081;|g" /etc/nginx/nginx.conf

## Copy site content 
#COPY conf/nginx.conf /etc/nginx/nginx.conf
#COPY content/ /var/www/html/
#
#RUN mkdir -p /var/www/html \
#  && mkdir -p /etc/nginx/conf.d \
#  && chown -R nginx:nginx /var/www/html /etc/nginx/ /var/log/nginx /usr/share/nginx /run/nginx.pid
#

# PORTS
EXPOSE 8081
# We can expose SSL if needed, but for now I skip it.
#EXPOSE 8443

USER nginx

CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

# set a health check
HEALTHCHECK --interval=5s \
            --timeout=5s \
            CMD curl -f http://127.0.0.1:8081 || exit 1

# Just for debug purposes let's have root user available for a while...
#USER root

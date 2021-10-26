FROM alpine:3.14.0

# expose ports
EXPOSE 80/tcp
EXPOSE 443/tcp

ENV DOMAIN localhost
ENV DOCUMENT_ROOT /public

# update apk repositories
RUN apk update

# upgrade all
RUN apk upgrade

# install console tools
RUN apk add \
    inotify-tools

# install zsh
RUN apk add \
    zsh \
    zsh-vcs

# configure zsh
ADD --chown=root:root include-docker/zshrc /etc/zsh/zshrc

# install php
RUN apk add \
    # use php8-fpm instead of php8-apache2
    php8-fpm \
    php8-bcmath \
    php8-common \
    php8-ctype \
    php8-curl \
    php8-dom \
    php8-exif \
    php8-fileinfo \
    php8-gd \ 
    php8-gettext \
    php8-json \
    php8-mbstring \
    php8-mysqli \
    php8-opcache \
    php8-openssl \
    php8-pecl-apcu \
    php8-pecl-imagick \
    php8-pdo \
    php8-pdo_mysql \
    php8-pdo_sqlite \
    php8-posix \
    php8-pecl-redis \
    php8-session \
    php8-simplexml \
    php8-soap \
    php8-sodium \
    php8-tokenizer \
    php8-xml \
    php8-xmlwriter \
    php8-zip

# configure php-fpm8
ADD --chown=root:root include-docker/www.conf /etc/php8/php-fpm.d/www.conf

# install composer
RUN apk add \
    composer

# locales
ENV MUSL_LOCPATH="/usr/share/i18n/locales/musl"
RUN apk add \
    musl-locales \
    musl-locales-lang


# install apache
RUN apk add \
    apache2 \
    apache2-ssl \
    apache2-proxy

# enable mod rewrite
RUN sed -i 's|#LoadModule rewrite_module modules/mod_rewrite.so|LoadModule rewrite_module modules/mod_rewrite.so|g' /etc/apache2/httpd.conf

# authorize all directives in .htaccess
RUN sed -i 's|    AllowOverride None|    AllowOverride All|g' /etc/apache2/httpd.conf

# change log files location
RUN mkdir -p /var/log/apache2
RUN sed -i 's| logs/error.log| /var/log/apache2/error.log|g' /etc/apache2/httpd.conf
RUN sed -i 's| logs/access.log| /var/log/apache2/access.log|g' /etc/apache2/httpd.conf

# change SSL log files location
RUN sed -i 's|ErrorLog logs/ssl_error.log|ErrorLog /var/log/apache2/error.log|g' /etc/apache2/conf.d/ssl.conf
RUN sed -i 's|TransferLog logs/ssl_access.log|TransferLog /var/log/apache2/access.log|g' /etc/apache2/conf.d/ssl.conf

# switch from mpm_prefork to mpm_event
RUN sed -i 's|LoadModule mpm_prefork_module modules/mod_mpm_prefork.so|#LoadModule mpm_prefork_module modules/mod_mpm_prefork.so|g' /etc/apache2/httpd.conf
RUN sed -i 's|#LoadModule mpm_event_module modules/mod_mpm_event.so|LoadModule mpm_event_module modules/mod_mpm_event.so|g' /etc/apache2/httpd.conf

# enable important apache modules
RUN sed -i 's|#LoadModule deflate_module modules/mod_deflate.so|LoadModule deflate_module modules/mod_deflate.so|g' /etc/apache2/httpd.conf
RUN sed -i 's|#LoadModule expires_module modules/mod_expires.so|LoadModule expires_module modules/mod_expires.so|g' /etc/apache2/httpd.conf
RUN sed -i 's|#LoadModule ext_filter_module modules/mod_ext_filter.so|LoadModule ext_filter_module modules/mod_ext_filter.so|g' /etc/apache2/httpd.conf

# authorize all changes in htaccess
RUN sed -i 's|Options Indexes FollowSymLinks|Options All|g' /etc/apache2/httpd.conf

# configure php-fpm to use unix socket
RUN sed -i 's|listen = 127.0.0.1:9000|listen = /var/run/php-fpm8.sock|g' /etc/php8/php-fpm.d/www.conf
RUN sed -i 's|;listen.owner = nobody|listen.owner = apache|g' /etc/php8/php-fpm.d/www.conf

# use set handler to route php requests to php-fpm
RUN sed -i 's|^DocumentRoot|<FilesMatch "\.php$">\n\
    SetHandler "proxy:unix:/var/run/php-fpm8.sock\|fcgi://localhost"\n\
</FilesMatch>\n\nDocumentRoot|g' /etc/apache2/httpd.conf

# update directory index to add php files
RUN sed -i 's|DirectoryIndex index.html|DirectoryIndex index.php index.html|g' /etc/apache2/httpd.conf

# change apache timeout for easier debugging
#RUN sed -i 's|^Timeout .*$|Timeout 600|g' /etc/apache2/conf.d/default.conf

# change php max execution time for easier debugging
#RUN sed -i 's|^max_execution_time .*$|max_execution_time = 600|g' /etc/php8/php.ini

# add http authentication support
RUN sed -i 's|^DocumentRoot|<VirtualHost _default_:80>\n    SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1\n</VirtualHost>\n\nDocumentRoot|g' /etc/apache2/httpd.conf
RUN sed -i 's|<VirtualHost _default_:443>|<VirtualHost _default_:443>\n\nSetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1|g' /etc/apache2/conf.d/ssl.conf

# Add the app
ADD --chown=root:root . /var/www/html$DOCUMENT_ROOT/

# add entry point script
ADD --chown=root:root include-docker/start.sh /tmp/start.sh

# make entry point script executable
RUN chmod +x /tmp/start.sh

# set working dir
WORKDIR /var/www/html/

# set entrypoint
ENTRYPOINT ["/tmp/start.sh"]

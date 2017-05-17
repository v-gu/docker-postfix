## -*- docker-image-name: lisnaz/postfix -*-
#
# Dockerfile for postfix
#

FROM lisnaz/alpine:latest
MAINTAINER Vincent Gu <g@v-io.co>

ENV POSTFIX_HOSTNAME= \
    POSTFIX_DOMAIN=$POSTFIX_HOSTNAME \
    POSTFIX_ORIGIN=$POSTFIX_HOSTNAME \
    POSTFIX_SMTP_PORT=25 \
    POSTFIX_SUBM_PORT=587 \
    POSTFIX_VA_DOMAINS=$POSTFIX_HOSTNAME \
    POSTFIX_VA_MAPS= \
    POSTFIX_TRANSPORTS= \
    \
    APP_DIR=/srv/postfix \
    PROC1="/usr/lib/postfix/master -d" \
    PROC1_SCRIPT_DIRNAME=postfix

# define service ports
EXPOSE $POSTFIX_SMTP_PORT/tcp \
       $POSTFIX_SUBM_PORT/tcp

# install software stack
RUN set -ex && \
    DEP=postfix && \
    apk add --update --no-cache $DEP && \
    rm -rf /var/cache/apk/* && \
    ln -s /etc/postfix /srv/postfix

# add runtime scripts
ADD scripts ${PROC_SCRIPTS_DIR}/

# define default directory
WORKDIR $APP_DIR

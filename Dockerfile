## -*- docker-image-name: lisnaz/postfix -*-
#
# Dockerfile for postfix
#
# need init: true
# need additional files:
#   - TLS Cert and key
#   - SASLDB file

FROM lisnaz/alpine:latest
MAINTAINER Vincent Gu <v@vgu.io>

# variable list
ENV POSTFIX_HOSTNAME            ""
ENV POSTFIX_DOMAIN              $POSTFIX_HOSTNAME
ENV POSTFIX_ORIGIN              $POSTFIX_DOMAIN
ENV POSTFIX_SMTP_PORT           25

ENV USE_SUBMISSION              no
ENV POSTFIX_SUBM_PORT           587
ENV POSTFIX_SMTP_TLS_CERT_FILE  ""
ENV POSTFIX_SMTP_TLS_KEY_FILE   ""
ENV SASLDB_PATH                 ""

ENV USE_POSTSRSD                no
ENV POSTFIX_VA_DOMAINS          $POSTFIX_HOSTNAME
ENV POSTFIX_VA_MAPS             ""
ENV POSTFIX_TRANSPORTS          ""
ENV SRS_DOMAIN                  example.com
ENV SRS_SECRET                  ""

# define service ports
EXPOSE $POSTFIX_SMTP_PORT/tcp \
       $POSTFIX_SUBM_PORT/tcp

# install software stack
RUN set -ex && \
    DEP='rsyslog cyrus-sasl postfix postsrsd opendkim' && \
    apk add --update --no-cache $DEP && \
    rm -rf /var/cache/apk/*

# add startup script
ADD imagescripts/run.sh ${APP_DIR}/run.sh

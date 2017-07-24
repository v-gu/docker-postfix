## -*- docker-image-name: lisnaz/postfix -*-
#
# Dockerfile for postfix
#

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

ENV APP_DIR                     /srv/postfix
ENV PROC1                       rsyslogd
ENV PROC1_ISDAEMON              true
ENV PROC2                       postfix start
ENV PROC2_ISDAEMON              true
ENV PROC2_SCRIPT_DIRNAME        postfix
ENV PROC3                       tail -f /var/log/maillog
ENV PROC3_ISDAEMON              false

# define service ports
EXPOSE $POSTFIX_SMTP_PORT/tcp \
       $POSTFIX_SUBM_PORT/tcp

# install software stack
RUN set -ex && \
    DEP='postfix cyrus-sasl rsyslog' && \
    apk add --update --no-cache $DEP && \
    rm -rf /var/cache/apk/* && \
    ln -s /etc/postfix /srv/postfix

# add runtime scripts
ADD scripts ${PROC_SCRIPTS_DIR}/

# define default directory
WORKDIR $APP_DIR

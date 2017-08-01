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
ENV POSTFIX_DIR                         "${ROOT_DIR}/postfix"
ENV POSTSRSD_DIR                        "${ROOT_DIR}/postsrsd"
ENV OPENDKIM_DIR                        "${ROOT_DIR}/opendkim"
ENV SASL2_DIR                           "${ROOT_DIR}/sasl2"

ENV POSTFIX_HOSTNAME                    ""
ENV POSTFIX_DOMAIN                      "${POSTFIX_HOSTNAME}"
ENV POSTFIX_ORIGIN                      "${POSTFIX_DOMAIN}"
ENV POSTFIX_SMTP_PORT                   25

ENV USE_SUBMISSION                      no
ENV POSTFIX_SUBM_PORT                   587
ENV POSTFIX_SMTP_TLS_CERT_FILE          ""
ENV POSTFIX_SMTP_TLS_KEY_FILE           ""
ENV SASLDB_PATH                         "/etc/sasldb2"
ENV DKIM_LISTEN_ADDR                    "127.0.0.1"
ENV DKIM_LISTEN_PORT                    "8891"
ENV DKIM_DOMAIN                         "${POSTFIX_DOMAIN}"
ENV DKIM_SELECTOR                       "mail"
ENV DKIM_KEY_FILE                       "/etc/opendkim.d/${DKIM_SELECTOR}.private"
ENV DKIM_TRUSTED_HOSTS                  "127.0.0.1\n::1\nlocalhost\n\n\*.example.com"

ENV USE_POSTSRSD                        no
ENV POSTFIX_VA_DOMAINS                  "${POSTFIX_DOMAIN}"
ENV POSTFIX_VA_MAPS                     ""
ENV POSTFIX_TRANSPORTS                  ""
ENV SRS_LISTEN_ADDR                     "127.0.0.1"
ENV SRS_DOMAIN                          "${POSTFIX_DOMAIN}"
ENV SRS_FORWARD_PORT                    10001
ENV SRS_REVERSE_PORT                    10002
ENV SRS_SEPARATOR                       "="
ENV SRS_TIMEOUT                         1800
ENV SRS_SECRET                          "${POSTSRSD_DIR}/postsrsd.secret"
ENV SRS_PID_FILE                        ""
ENV SRS_RUN_AS                          ""
ENV SRS_CHROOT                          ""
ENV SRS_EXCLUDE_DOMAINS                 ""
ENV SRS_REWRITE_HASH_LEN                4
ENV SRS_VALIDATE_HASH_MINLEN            4

# define service ports
EXPOSE $POSTFIX_SMTP_PORT/tcp \
       $POSTFIX_SUBM_PORT/tcp

# install software stack
RUN set -ex && \
    DEP='rsyslog cyrus-sasl postfix postsrsd opendkim' && \
    apk add --update --no-cache $DEP && \
    rm -rf /var/cache/apk/*

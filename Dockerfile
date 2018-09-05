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
ENV POSTFIX_MYNETWORKS                  ""
ENV POSTFIX_HOSTNAME                    ""
ENV POSTFIX_DOMAIN                      "${POSTFIX_HOSTNAME}"
ENV POSTFIX_ORIGIN                      "${POSTFIX_DOMAIN}"

# local alias
ENV ALIAS_MAPS                          ""

# virtual local alias
ENV VIRTUAL_ALIAS_DOMAINS               ""
ENV VIRTUAL_ALIAS_MAPS                  ""

# virtual alias mainbox domain class
ENV VIRTUAL_MAILBOX_DOMAINS             ""
ENV VIRTUAL_MAILBOX_MAPS                ""

# relay domain class
ENV RELAY_DOMAINS                       ""
ENV RELAY_RECIPIENT_MAPS                ""
ENV SENDER_DEPENDENT_RELAYHOST_MAPS     ""
ENV RELAY_TRANSPORT                     "relay"
ENV RELAY_HOST                          ""

# default domain class
ENV SENDER_DEPENDENT_DEFAULT_TRANSPORT_MAPS ""
ENV DEFAULT_TRANSPORT                   "smtp"
ENV TRANSPORT_MAPS                      ""

# DKIM
ENV DKIM_DOMAIN                         "${POSTFIX_DOMAIN}"
ENV DKIM_TRUSTED_HOSTS                  "127.0.0.1\n::1\nlocalhost\n\n\*.example.com"

ENV SRS_LISTEN_ADDR                     "127.0.0.1"
ENV SRS_DOMAIN                          "${POSTFIX_DOMAIN}"
ENV SRS_FORWARD_PORT                    10001
ENV SRS_REVERSE_PORT                    10002
ENV SRS_SEPARATOR                       "="
ENV SRS_TIMEOUT                         1800
ENV SRS_SECRET_FILE                     "${POSTSRSD_DIR}/postsrsd.secret"
ENV SRS_PID_FILE                        ""
ENV SRS_RUN_AS                          ""
ENV SRS_CHROOT                          ""
ENV SRS_EXCLUDE_DOMAINS                 ""
ENV SRS_REWRITE_HASH_LEN                4
ENV SRS_VALIDATE_HASH_MINLEN            4

ENV USE_SMTPD                           no
ENV SMTPD_PORT                          25
ENV SMTPD_RELAY_RESTRICTIONS            permit_auth_destination,reject
ENV SMTPD_REJECT_UNLISTED_RECIPIENT     yes

ENV USE_SUBMISSION                      no
ENV SUBM_PORT                           587
ENV SUBM_TLS_SECURITY_LEVEL             encrypt
ENV SUBM_SASL_AUTH                      yes
ENV SUBM_RELAY_RESTRICTIONS             permit_sasl_authenticated,reject
ENV SUBM_REJECT_UNLISTED_RECIPIENT      no
ENV SUBM_SASL_DB_FILE                   "${ROOT_DIR}/sasldb/sasldb2"
ENV SUBM_SASL_USERNAME                  "smtp"
ENV SUBM_SASL_PASSWORD                  ""

# define service ports
EXPOSE $SMTPD_PORT/tcp \
       $SUBM_PORT/tcp

# install software stack
RUN set -ex && \
    DEP='rsyslog cyrus-sasl postfix postsrsd opendkim opendkim-utils' && \
    apk add --update --no-cache $DEP && \
    rm -rf /var/cache/apk/*

VOLUME /etc/opendkim
VOLUME "${ROOT_DIR}"/tls

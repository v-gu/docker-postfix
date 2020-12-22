## -*- docker-image-name: lisnaz/postfix -*-
#
# Dockerfile for postfix
#
# need init: false
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
ENV VIRTUAL_MAILBOX_BASE                "${ROOT_DIR}/mail"
ENV VIRTUAL_MINIMUM_UID                 1
ENV VIRTUAL_UID_MAPS                    "static:5000"
ENV VIRTUAL_GID_MAPS                    "static:5000"

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

# BCC
ENV SENDER_BCC_MAPS                     ""
ENV RECIPIENT_BCC_MAPS                  ""

# DKIM
ENV DKIM_LISTEN_ADDR                    opendkim
ENV DKIM_LISTEN_PORT                    9901

ENV SRS_LISTEN_ADDR                     postsrsd
ENV SRS_DOMAIN                          "${POSTFIX_DOMAIN}"
ENV SRS_FORWARD_PORT                    10001
ENV SRS_REVERSE_PORT                    10002

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

ENV SMTP_TLS_SECURITY_LEVEL             "may"

# define service ports
EXPOSE $SMTPD_PORT/tcp \
       $SUBM_PORT/tcp

# install software stack
RUN set -ex && \
    DEP='postfix' && \
    apk add --update --no-cache $DEP && \
    rm -rf /var/cache/apk/*

VOLUME "${ROOT_DIR}"/tls
VOLUME "${VIRTUAL_MAILBOX_BASE}"

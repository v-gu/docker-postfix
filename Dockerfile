## -*- docker-image-name: lisnaz/postfix -*-
#
# Dockerfile for postfix
#

FROM alpine:latest
MAINTAINER Vincent.Gu <g@v-io.co>

ENV POSTFIX_SMTP_PORT    25
ENV POSTFIX_SUBM_PORT    587
EXPOSE $POSTFIX_SMTP_PORT/tcp
EXPOSE $POSTFIX_SUBM_PORT/tcp

ADD entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]

# install postfix
ENV INS_PKG=postfix
RUN set -ex \
&& apk add --update $INS_PKG \
&& rm -rf /var/cache/apk/*

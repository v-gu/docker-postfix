#!/usr/bin/env sh

set -e

# ======= POSTFIX CONFIG ======
POSTFIX_HOSTNAME=${POSTFIX_HOSTNAME}
POSTFIX_DOMAIN=${POSTFIX_DOMAIN:-$POSTFIX_HOSTNAME}
POSTFIX_ORIGIN=${POSTFIX_ORIGIN:-$POSTFIX_HOSTNAME}
POSTFIX_SMTP_PORT=${POSTFIX_SMTP_PORT:-25}
POSTFIX_SUBM_PORT=${POSTFIX_SUBM_PORT:-587}
POSTFIX_VA_DOMAIN=${POSTFIX_VA_DOMAIN:-$POSTFIX_HOSTNAME}
POSTFIX_VA_ENTRIES=${POSTFIX_VA_ENTRIES}
POSTFIX_TRANSPORTS=${POSTFIX_TRANSPORTS}

# update configs
cd /etc/postfix

# add main.cf entries
echo "$(awk -v var=$POSTFIX_HOSTNAME '/^myhostname =/{f=1}END{ if (!f) {print "myhostname = "var}}1' main.cf)" > main.cf
echo "$(awk -v var=$POSTFIX_DOMAIN '/^mydomain =/{f=1}END{ if (!f) {print "mydomain = "var}}1' main.cf)" > main.cf
echo "$(awk -v var=$POSTFIX_ORIGIN '/^myorigin =/{f=1}END{ if (!f) {print "myorigin = "var}}1' main.cf)" > main.cf

# add virtual entries
echo "$(awk -v var=$POSTFIX_VA_DOMAIN '/^virtual_alias_domains =/{f=1}END{ if (!f) {print "virtual_alias_domains = "var}}1' main.cf)" > main.cf
echo "$(awk '/^virtual_alias_maps =/{f=1}END{ if (!f) {print "virtual_alias_maps = hash:/etc/postfix/virtual"}}1' main.cf)" > main.cf
echo -e "$POSTFIX_VA_ENTRIES" > virtual
postmap virtual

# add transport entries
echo "$(awk '/^transport_maps =/{f=1}END{ if (!f) {print "transport_maps = hash:/etc/postfix/transport"}}1' main.cf)" > main.cf
echo -e "$POSTFIX_TRANSPORTS" > transport
postmap transport

# start service
echo "Starting Postfix..."
postfix start
sleep 1000000d

#!/usr/bin/env sh
set -e

postfix_confdir=/etc/postfix

# add main.cf entries
echo "$(awk -v var=$POSTFIX_HOSTNAME '/^myhostname =/{f=1}END{ if (!f) {print "myhostname = "var}}1' ${postfix_confdir}/main.cf)" > ${postfix_confdir}/main.cf
echo "$(awk -v var=$POSTFIX_DOMAIN '/^mydomain =/{f=1}END{ if (!f) {print "mydomain = "var}}1' ${postfix_confdir}/main.cf)" > ${postfix_confdir}/main.cf
echo "$(awk -v var=$POSTFIX_ORIGIN '/^myorigin =/{f=1}END{ if (!f) {print "myorigin = "var}}1' ${postfix_confdir}/main.cf)" > ${postfix_confdir}/main.cf

# add virtual entries
echo "$(awk -v var=$POSTFIX_VA_DOMAIN '/^virtual_alias_domains =/{f=1}END{ if (!f) {print "virtual_alias_domains = "var}}1' ${postfix_confdir}/main.cf)" > ${postfix_confdir}/main.cf
echo "$(awk '/^virtual_alias_maps =/{f=1}END{ if (!f) {print "virtual_alias_maps = hash:/etc/postfix/virtual"}}1' ${postfix_confdir}/main.cf)" > ${postfix_confdir}/main.cf
echo -e "$POSTFIX_VA_ENTRIES" > ${postfix_confdir}/virtual
postmap ${postfix_confdir}/virtual

# add transport entries
echo "$(awk '/^transport_maps =/{f=1}END{ if (!f) {print "transport_maps = hash:/etc/postfix/transport"}}1' ${postfix_confdir}/main.cf)" > ${postfix_confdir}/main.cf
echo -e "$POSTFIX_TRANSPORTS" > ${postfix_confdir}/transport
postmap ${postfix_confdir}/transport

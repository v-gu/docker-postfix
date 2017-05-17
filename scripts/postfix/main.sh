#!/usr/bin/env bash

if [ "${INIT_DEBUG}" == true ]; then
    set -x
fi

POSTFIX_HOSTNAME="${POSTFIX_HOSTNAME}"
POSTFIX_DOMAIN="${POSTFIX_DOMAIN:-$POSTFIX_HOSTNAME}"
POSTFIX_ORIGIN="${POSTFIX_ORIGIN:-$POSTFIX_HOSTNAME}"
POSTFIX_SMTP_PORT="${POSTFIX_SMTP_PORT:-smtp}"
POSTFIX_SUBM_PORT="${POSTFIX_SUBM_PORT:-submisstion}"
POSTFIX_VA_DOMAINS="${POSTFIX_VA_DOMAINS}"
POSTFIX_VA_MAPS="${POSTFIX_VA_MAPS}"
POSTFIX_TRANSPORTS="${POSTFIX_TRANSPORTS}"

# modify master.cf
if [ -z "${POSTFIX_SMTP_PORT+x}" -o "$POSTFIX_SMTP_PORT" == "25" ]; then
    POSTFIX_SMTP_PORT=smtp
fi
if [ -z "${POSTFIX_SUBM_PORT+x}" -o "$POSTFIX_SUBM_PORT" == "587" ]; then
    POSTFIX_SUBM_PORT=submission
fi
master="$(< ${APP_DIR}/master.cf)"
echo "${master}" | \
    gawk \
        -v POSTFIX_SMTP_PORT="$POSTFIX_SMTP_PORT" \
        -v POSTFIX_SUBM_PORT="$POSTFIX_SUBM_PORT" \
        ' \
        /^#*smtp[[:blank:]]+.*smtpd[[:blank:]]*/{smtp_port=1; match($0, /^(#*)smtp([[:blank:]]+.*smtpd[[:blank:]]*)/, arr); print POSTFIX_SMTP_PORT arr[2]; next}
        /^#*submission[[:blank:]]+.*smtpd[[:blank:]]*/{subm_port=1; match($0, /^(#*)submission([[:blank:]]+.*smtpd[[:blank:]]*)/, arr); print POSTFIX_SUBM_PORT arr[2]; next}
        {print $0}
        END {print ""} \
        END {if (!smtp_port) {print POSTFIX_SMTP_PORT " inet n - n - - smtpd"}} \
        END {if (!subm_port) {print POSTFIX_SUBM_PORT " inet n - n - - smtpd"}} \
        ' \
        > "${APP_DIR}/master.cf"

# add main.cf entries
main="$(< ${APP_DIR}/main.cf)"
echo "${main}" | \
    gawk \
        -v POSTFIX_HOSTNAME="$POSTFIX_HOSTNAME" \
        -v POSTFIX_DOMAIN="$POSTFIX_DOMAIN" \
        -v POSTFIX_ORIGIN="$POSTFIX_ORIGIN" \
        -v POSTFIX_VA_DOMAINS="$POSTFIX_VA_DOMAINS" \
        -v POSTFIX_VA_MAPS="$POSTFIX_VA_MAPS" \
        -v POSTFIX_TRANSPORTS="$POSTFIX_TRANSPORTS" \
        ' \
        /^myhostname[[:blank:]]*=/{myhostname=1; if (myhostname) {sub(/=.*$/, "= "POSTFIX_HOSTNAME)}} \
        /^mydomain[[:blank:]]*=/{mydomain=1; if (mydomain) {sub(/=.*$/, "= "POSTFIX_DOMAIN)}} \
        /^myorigin[[:blank:]]*=/{myorigin=1; if (myorigin) {sub(/=.*$/, "= "POSTFIX_ORIGIN)}} \
        /^virtual_alias_domains[[:blank:]]*=/{virtual_alias_domains=1; if (virtual_alias_domains) {sub(/=.*$/, "= "POSTFIX_VA_DOMAINS)}} \
        /^virtual_alias_maps[[:blank:]]*=/{virtual_alias_maps=1; if (virtual_alias_maps) {sub(/=.*$/, "= "POSTFIX_VA_MAPS)}} \
        /^transport_maps[[:blank:]]*=/{transport_maps=1; if (transport_maps) {sub(/=.*$/, "= "POSTFIX_TRANSPORTS)}} \
        {print $0}
        END {print ""} \
        END {if (!myhostname) {print "myhostname = "POSTFIX_HOSTNAME}} \
        END {if (!mydomain) {print "mydomain = "POSTFIX_DOMAIN}} \
        END {if (!myorigin) {print "myorigin = "POSTFIX_ORIGIN}} \
        END {if (!virtual_alias_domains) {print "virtual_alias_domains = "POSTFIX_VA_DOMAINS}} \
        END {if (!virtual_alias_maps) {print "virtual_alias_maps = "POSTFIX_VA_MAPS}} \
        END {if (!transport_maps) {print "transport_maps = "POSTFIX_TRANSPORTS}} \
        ' \
        > "${APP_DIR}/main.cf"

# add virtual entries
echo -e "$POSTFIX_VA_MAPS" > ${APP_DIR}/virtual
postmap ${APP_DIR}/virtual

# add transport entries
echo -e "$POSTFIX_TRANSPORTS" > ${APP_DIR}/transport
postmap ${APP_DIR}/transport

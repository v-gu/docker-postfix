#!/usr/bin/env bash

if [ "${INIT_DEBUG}" == true ]; then
    set -x
fi

POSTFIX_HOSTNAME="${POSTFIX_HOSTNAME}"
POSTFIX_DOMAIN="${POSTFIX_DOMAIN:-$POSTFIX_HOSTNAME}"
POSTFIX_ORIGIN="${POSTFIX_ORIGIN:-$POSTFIX_HOSTNAME}"
POSTFIX_SMTP_PORT="${POSTFIX_SMTP_PORT:-smtp}"

USE_SUBMISSION="${USE_SUBMISSION:-no}"
POSTFIX_SUBM_PORT="${POSTFIX_SUBM_PORT:-submisstion}"
POSTFIX_SMTP_TLS_CERT_FILE="${POSTFIX_SMTP_TLS_CERT_FILE}"
POSTFIX_SMTP_TLS_KEY_FILE="${POSTFIX_SMTP_TLS_KEY_FILE}"
SASLDB_PATH="${SASLDB_PATH:-/etc/sasldb2}"

USE_POSTSRSD="${USE_POSTSRSD:-no}"
POSTFIX_VA_DOMAINS="${POSTFIX_VA_DOMAINS}"
POSTFIX_VA_MAPS="${POSTFIX_VA_MAPS}"
POSTFIX_TRANSPORTS="${POSTFIX_TRANSPORTS}"

# init master.cf
if [ -z "${POSTFIX_SMTP_PORT+x}" -o "$POSTFIX_SMTP_PORT" == "25" ]; then
    POSTFIX_SMTP_PORT=smtp
fi
cat <<EOF > ${APP_DIR}/master.cf
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (no)    (never) (100)
# ==========================================================================
${POSTFIX_SMTP_PORT}    inet n       -       n       -       -       smtpd
pickup    unix  n       -       n       60      1       pickup
cleanup   unix  n       -       n       -       0       cleanup
qmgr      unix  n       -       n       300     1       qmgr
tlsmgr    unix  -       -       n       1000?   1       tlsmgr
rewrite   unix  -       -       n       -       -       trivial-rewrite
bounce    unix  -       -       n       -       0       bounce
defer     unix  -       -       n       -       0       bounce
trace     unix  -       -       n       -       0       bounce
verify    unix  -       -       n       -       1       verify
flush     unix  n       -       n       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       n       -       -       smtp
relay     unix  -       -       n       -       -       smtp
showq     unix  n       -       n       -       -       showq
error     unix  -       -       n       -       -       error
retry     unix  -       -       n       -       -       error
discard   unix  -       -       n       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       n       -       -       lmtp
anvil     unix  -       -       n       -       1       anvil
scache    unix  -       -       n       -       1       scache
EOF

# init main.cf
cat <<EOF >${APP_DIR}/main.cf
myhostname = ${POSTFIX_HOSTNAME}
mydomain = ${POSTFIX_DOMAIN}
myorigin = ${POSTFIX_ORIGIN}
virtual_alias_domains = ${POSTFIX_VA_DOMAINS}
virtual_alias_maps = hash:${APP_DIR}/virtual
transport_maps = hash:${APP_DIR}/transport
EOF

# add submission configs if required
if [ "${USE_SUBMISSION}" == 'yes' ]; then
    if [ -z "${POSTFIX_SUBM_PORT+x}" -o "$POSTFIX_SUBM_PORT" == "587" ]; then
        POSTFIX_SUBM_PORT=submission
    fi

    cat <<EOF >> ${APP_DIR}/master.cf
${POSTFIX_SUBM_PORT}    inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=may
  -o smtpd_tls_cert_file=${POSTFIX_SMTP_TLS_CERT_FILE}
  -o smtpd_tls_key_file=${POSTFIX_SMTP_TLS_KEY_FILE}
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF

    mkdir -p ${APP_DIR}/sasl2 && \
        cat <<EOF >${APP_DIR}/sasl2/smtpd.conf
sasldb_path: ${SASLDB_PATH}
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
log_level: 7
EOF
    ln -s ${APP_DIR}/sasl2/smtpd.conf /usr/lib/sasl2/smtpd.conf
fi

#add SRS configs if required
if [ "${USE_POSTSRSD}" == 'yes' ]; then
    cat <<EOF >> ${APP_DIR}/main.cf
sender_canonical_maps = tcp:localhost:10001
sender_canonical_classes = envelope_sender
recipient_canonical_maps = tcp:localhost:10002
recipient_canonical_classes= envelope_recipient,header_recipient
EOF

    # add virtual entries
    echo -e "$POSTFIX_VA_MAPS" > ${APP_DIR}/virtual
    postmap ${APP_DIR}/virtual

    # add transport entries
    echo -e "$POSTFIX_TRANSPORTS" > ${APP_DIR}/transport
    postmap ${APP_DIR}/transport
fi

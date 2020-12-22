#!/usr/bin/env bash

# init vars
POSTFIX_DIR="${POSTFIX_DIR:-${ROOT_DIR}/postfix}"
SASL_CONF_DIR="${SASL_CONF_DIR:-${ROOT_DIR}/sasl2}"

POSTFIX_MYNETWORKS="${POSTFIX_MYNETWORKS}"
POSTFIX_HOSTNAME="${POSTFIX_HOSTNAME}"
POSTFIX_DOMAIN="${POSTFIX_DOMAIN}"
POSTFIX_ORIGIN="${POSTFIX_ORIGIN:-${POSTFIX_DOMAIN}}"

# local domain class
ALIAS_MAPS="${ALIAS_MAPS}"

# virtual alias domain class
VIRTUAL_ALIAS_DOMAINS="${VIRTUAL_ALIAS_DOMAINS}"
VIRTUAL_ALIAS_MAPS="${VIRTUAL_ALIAS_MAPS}"

# virtual alias mainbox domain class
VIRTUAL_MAILBOX_DOMAINS="${VIRTUAL_MAILBOX_DOMAINS}"
VIRTUAL_MAILBOX_MAPS="${VIRTUAL_MAILBOX_MAPS}"
VIRTUAL_MAILBOX_BASE="${VIRTUAL_MAILBOX_BASE:-${ROOT_DIR}/mail}"
VIRTUAL_MINIMUM_UID="${VIRTUAL_MINIMUM_UID:-1}"
VIRTUAL_UID_MAPS="${VIRTUAL_UID_MAPS:-static:5000}"
VIRTUAL_GID_MAPS="${VIRTUAL_GID_MAPS:-static:5000}"

# relay domain class
RELAY_DOMAINS="${RELAY_DOMAINS}"
RELAY_RECIPIENT_MAPS="${RELAY_RECIPIENT_MAPS}"
SENDER_DEPENDENT_RELAYHOST_MAPS="${SENDER_DEPENDENT_RELAYHOST_MAPS}"
RELAY_TRANSPORT="${RELAY_TRANSPORT:-relay}"
RELAY_HOST="${RELAY_HOST}"

# default domain class
SENDER_DEPENDENT_DEFAULT_TRANSPORT_MAPS="${SENDER_DEPENDENT_DEFAULT_TRANSPORT_MAPS}"
DEFAULT_TRANSPORT="${DEFAULT_TRANSPORT:-smtp}"
TRANSPORT_MAPS="${TRANSPORT_MAPS}"

# BCC
SENDER_BCC_MAPS="${SENDER_BCC_MAPS}"
RECIPIENT_BCC_MAPS="${RECIPIENT_BCC_MAPS}"

# DKIM
DKIM_LISTEN_ADDR="${DKIM_LISTEN_ADDR:-opendkim}"
DKIM_LISTEN_PORT="${DKIM_LISTEN_PORT:-9901}"

# SRS
SRS_LISTEN_ADDR="${SRS_LISTEN_ADDR:-postsrsd}"
SRS_DOMAIN="${SRS_DOMAIN:-${POSTFIX_DOMAIN}}"
SRS_FORWARD_PORT="${SRS_FORWARD_PORT:-10001}"
SRS_REVERSE_PORT="${SRS_REVERSE_PORT:-10002}"

# smtp ingress service
USE_SMTPD="${USE_SMTPD:-no}"
SMTPD_PORT="${SMTPD_PORT:-smtp}"
SMTPD_RELAY_RESTRICTIONS="${SMTPD_RELAY_RESTRICTIONS:-permit_auth_destination,reject}"
SMTPD_REJECT_UNLISTED_RECIPIENT="${SMTPD_REJECT_UNLISTED_RECIPIENT:-yes}"

# submission ingress service
USE_SUBMISSION="${USE_SUBMISSION:-no}"
SUBM_PORT="${SUBM_PORT:-submission}"
SUBM_TLS_SECURITY_LEVEL="${SUBM_TLS_SECURITY_LEVEL:-encrypt}"
SUBM_TLS_CERT_FILE="${SUBM_TLS_CERT_FILE:-${ROOT_DIR}/tls/${POSTFIX_DOMAIN}.cert}"
SUBM_TLS_KEY_FILE="${SUBM_TLS_KEY_FILE:-${ROOT_DIR}/tls/${POSTFIX_DOMAIN}.key}"
SUBM_SASL_AUTH="${SUBM_SASL_AUTH:yes}"
SUBM_RELAY_RESTRICTIONS="${SUBM_RELAY_RESTRICTIONS:-permit_sasl_authenticated,reject}"
SUBM_REJECT_UNLISTED_RECIPIENT="${SUBM_REJECT_UNLISTED_RECIPIENT:-no}"
SUBM_SASL_DB_FILE="${SUBM_SASL_DB_FILE:-${ROOT_DIR}/sasldb/sasldb2}"
SUBM_SASL_USERNAME="${SUBM_SASL_USERNAME:-smtp}"
SUBM_SASL_PASSWORD="${SUBM_SASL_PASSWORD}"

# smtp service
SMTP_TLS_SECURITY_LEVEL="${SMTP_TLS_SECURITY_LEVEL:-may}"

# check prerequisite variables
if [ -z "${POSTFIX_DOMAIN}" ]; then
    echo "postfix's domain is null"
    exit 1
fi

if [ "${USE_SUBMISSION}" == "yes" ]; then
    if [ ! -f "${SUBM_SASL_DB_FILE}" ] && [ -z "${SUBM_SASL_PASSWORD}" ]; then
        echo "submission's sasl database file not exist at path '${SUBM_SASL_DB_FILE}', nor password provided"
        exit 1
    fi
fi

# preparing app directories
ln -sn /etc/postfix ${POSTFIX_DIR}

# start rsyslog
# rm -f /var/run/rsyslogd.pid
# rsyslogd

# init postfix
## init main.cf
cat <<EOF >${POSTFIX_DIR}/main.cf

# log settings
maillog_file=/dev/stdout

# misc settings
compatibility_level =  9999
header_size_limit = 4096000
EOF

[ -n "${POSTFIX_MYNETWORKS}" ] && cat <<EOF >>${POSTFIX_DIR}/main.cf

mynetworks = ${POSTFIX_MYNETWORKS}
EOF

cat <<EOF >>${POSTFIX_DIR}/main.cf

myhostname = ${POSTFIX_HOSTNAME}
mydomain = ${POSTFIX_DOMAIN}
myorigin = ${POSTFIX_ORIGIN}
EOF

# local domain class
if [ -n "${ALIAS_MAPS}" ]; then
    cat <<EOF >>${POSTFIX_DIR}/main.cf

# local domain class
alias_maps = hash:${POSTFIX_DIR}/alias
EOF

    # add alias db entries
    echo -e "${ALIAS_MAPS}" > ${POSTFIX_DIR}/alias
    postmap ${POSTFIX_DIR}/alias
    rm ${POSTFIX_DIR}/alias
fi

# virtual alias domain class
if [ -n "${VIRTUAL_ALIAS_MAPS}" ]; then
    cat <<EOF >>${POSTFIX_DIR}/main.cf

# virtual alias domain class
virtual_alias_domains = ${VIRTUAL_ALIAS_DOMAINS}
virtual_alias_maps = hash:${POSTFIX_DIR}/virtual
EOF
    # add virtual db entries
    echo -e "${VIRTUAL_ALIAS_MAPS}" > ${POSTFIX_DIR}/virtual
    postmap ${POSTFIX_DIR}/virtual
    rm ${POSTFIX_DIR}/virtual
fi

# virtual mailbox domain class
if [ -n "${VIRTUAL_MAILBOX_DOMAINS}" ]; then
    cat <<EOF >>${POSTFIX_DIR}/main.cf

# virtual mailbox domain class
virtual_mailbox_domains = ${VIRTUAL_MAILBOX_DOMAINS}
virtual_mailbox_maps = hash:${POSTFIX_DIR}/vmailbox
virtual_mailbox_base = ${VIRTUAL_MAILBOX_BASE}
virtual_minimum_uid = ${VIRTUAL_MINIMUM_UID}
virtual_uid_maps = ${VIRTUAL_UID_MAPS}
virtual_gid_maps = ${VIRTUAL_GID_MAPS}
EOF
    # add vmailbox db entries
    echo -e "${VIRTUAL_MAILBOX_MAPS}" > ${POSTFIX_DIR}/vmailbox
    postmap ${POSTFIX_DIR}/vmailbox
    rm ${POSTFIX_DIR}/vmailbox

    # add static user
    addgroup -g "${VIRTUAL_GID_MAPS##*:}" email
    adduser -u "${VIRTUAL_UID_MAPS##*:}" -G email -H -D email

    # add mailbox directory
    mkdir -p "${VIRTUAL_MAILBOX_BASE}"
    chmod -R g+s,o-rwX "${VIRTUAL_MAILBOX_BASE}"
    chown -R email:email "${VIRTUAL_MAILBOX_BASE}"
fi

# relay domain class
if [ -n "${RELAY_DOMAIN}" ]; then
    cat <<EOF >>${POSTFIX_DIR}/main.cf

# relay domain class
relay_domains = "${RELAY_DOMAINS}"
relay_recipient_maps = hash:${POSTFIX_DIR}/relay_recipient
sender_dependent_relayhost_maps = hash:${POSTFIX_DIR}/sender_dependent_relayhost
relay_transport = "${RELAY_TRANSPORT}"
relay_host = "${RELAY_HOST}"
EOF
    # add relay recipient db entries
    echo -e "${RELAY_RECIPIENT_MAPS}" > ${POSTFIX_DIR}/relay_recipient
    postmap ${POSTFIX_DIR}/relay_recipient
    rm ${POSTFIX_DIR}/relay_recipient
    # add sender dependent relayhost db entries
    echo -e "${SENDER_DEPENDENT_RELAYHOST_MAPS}" > ${POSTFIX_DIR}/sender_dependent_relayhost
    postmap ${POSTFIX_DIR}/sender_dependent_relayhost
    rm ${POSTFIX_DIR}/sender_dependent_relayhost
fi

# default domain class
cat <<EOF >>${POSTFIX_DIR}/main.cf

# default domain class
EOF
if [ -n "${SENDER_DEPENDENT_DEFAULT_TRANSPORT_MAPS}" ]; then
    cat <<EOF >>${POSTFIX_DIR}/main.cf
sender_dependent_default_transport_maps = hash:${POSTFIX_DIR}/sender_dependent_default_transport
EOF
    # add db entries
    echo -e "${SENDER_DEPENDENT_DEFAULT_TRANSPORT_MAPS}" > ${POSTFIX_DIR}/sender_dependent_default_transport
    postmap ${POSTFIX_DIR}/sender_dependent_default_transport
    rm ${POSTFIX_DIR}/sender_dependent_default_transport
fi

[ -n "${DEFAULT_TRANSPORT}" ] && cat <<EOF >>${POSTFIX_DIR}/main.cf
default_transport = ${DEFAULT_TRANSPORT}
EOF

if [ -n "${TRANSPORT_MAPS}" ]; then
    cat <<EOF >>${POSTFIX_DIR}/main.cf
transport_maps = hash:${POSTFIX_DIR}/transport
EOF
    # add db entries
    echo -e "${TRANSPORT_MAPS}" > ${POSTFIX_DIR}/transport
    postmap ${POSTFIX_DIR}/transport
    rm ${POSTFIX_DIR}/transport
fi

# bcc
if [ -n "${SENDER_BCC_MAPS}" ]; then
    cat <<EOF >>${POSTFIX_DIR}/main.cf
sender_bcc_maps = hash:${POSTFIX_DIR}/sender_bcc
EOF
    # add db entries
    echo -e "${SENDER_BCC_MAPS}" > ${POSTFIX_DIR}/sender_bcc
    postmap ${POSTFIX_DIR}/sender_bcc
    rm ${POSTFIX_DIR}/sender_bcc
fi
if [ -n "${RECIPIENT_BCC_MAPS}" ]; then
    cat <<EOF >>${POSTFIX_DIR}/main.cf
recipient_bcc_maps = hash:${POSTFIX_DIR}/recipient_bcc
EOF
    # add db entries
    echo -e "${RECIPIENT_BCC_MAPS}" > ${POSTFIX_DIR}/recipient_bcc
    postmap ${POSTFIX_DIR}/recipient_bcc
    rm ${POSTFIX_DIR}/recipient_bcc
fi

# # add opendkim config
cat <<EOF >>${POSTFIX_DIR}/main.cf

# DKIM
milter_protocol = 2
milter_default_action = accept
# OpenDKIM runs on port ${DKIM_LISTEN_ADDR}:${DKIM_LISTEN_PORT}.
smtpd_milters = inet:${DKIM_LISTEN_ADDR}:${DKIM_LISTEN_PORT}
non_smtpd_milters = inet:${DKIM_LISTEN_ADDR}:${DKIM_LISTEN_PORT}
EOF

# add SRS config
cat <<EOF >> ${POSTFIX_DIR}/main.cf

# SRS
sender_canonical_maps = tcp:${SRS_LISTEN_ADDR}:${SRS_FORWARD_PORT}
sender_canonical_classes = envelope_sender
recipient_canonical_maps = tcp:${SRS_LISTEN_ADDR}:${SRS_REVERSE_PORT}
recipient_canonical_classes= envelope_recipient,header_recipient
EOF


# default smtpd ingress config
cat <<EOF >>${POSTFIX_DIR}/main.cf

# smtpd ingress
smtpd_relay_restrictions = reject
smtpd_reject_unlisted_recipient = yes
EOF

# init master.cf
cat <<EOF > ${POSTFIX_DIR}/master.cf
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (no)    (never) (100)
# ==========================================================================
postlog   unix-dgram n  -       n       -       1       postlogd
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

# smtpd in master.cf
if [ "${USE_SMTPD}" == "yes" ]; then
    if [ -z "${SMTP_PORT}" ] || [ "${SMTP_PORT}" == "25" ]; then
        SMTP_PORT=smtp
    fi
    cat <<EOF >> ${POSTFIX_DIR}/master.cf
${SMTP_PORT}    inet n       -       n       -       -       smtpd
  -o smtpd_reject_unlisted_recipient=${SMTPD_REJECT_UNLISTED_RECIPIENT}
  -o smtpd_relay_restrictions=${SMTPD_RELAY_RESTRICTIONS}
EOF
fi

# submission config
if [ "${USE_SUBMISSION}" == 'yes' ]; then
    # sasl config
    cat <<EOF >> ${POSTFIX_DIR}/main.cf

# # smtpd submission sasl config
# smtp_sasl_password_maps = ${SMTP_SASL_PASSWORD_MAPS}
# EOF
#     mkdir -p /etc/sasl2 && ln -sn /etc/sasl2 "${SASL_CONF_DIR}"
#     cat <<EOF >"${SASL_CONF_DIR}"/smtpd.conf
# sasldb_path: ${SUBM_SASL_DB_FILE}
# pwcheck_method: auxprop
# auxprop_plugin: sasldb
# mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
# log_level: 7
# EOF
#     if [ "${SASL_CONF_DIR}" != "/etc/sasl2" ]; then
#         ln -s "${SASL_CONF_DIR}"/smtpd.conf /etc/sasl2/smtpd.conf
#     fi

    # tls config
    if [ ! -f "${SUBM_TLS_KEY_FILE}" ]; then
        echo "submission's TLS key not exist at '${SUBM_TLS_KEY_FILE}'"
    fi
    if [ ! -f "${SUBM_TLS_CERT_FILE}" ]; then
        echo "submission's TLS certification not exist at '${SUBM_TLS_CERT_FILE}'"
    fi
    if [ -f "${SUBM_TLS_KEY_FILE}" ] && [ -f "${SUBM_TLS_CERT_FILE}" ]; then
        echo "submission's TLS key/cert is provided with ${SUBM_TLS_KEY_FILE} and ${SUBM_TLS_CERT_FILE}"
    else
        # create rsa key-pair
        mkdir -p "${ROOT_DIR}/tls"
        cd "${ROOT_DIR}/tls"
        openssl req \
                -new -newkey rsa:2048 \
                -days 100000 \
                -nodes \
                -x509 \
                -subj "/C=US/ST=State/L=Location/O=example.com/CN=${POSTFIX_DOMAIN}" \
                -keyout "${POSTFIX_DOMAIN}".key \
                -out "${POSTFIX_DOMAIN}".cert
        chmod 400 "${POSTFIX_DOMAIN}".key
        chmod 400 "${POSTFIX_DOMAIN}".cert
        chown postfix:postfix *
        cd -
        echo "submission's TLS key/cert generated"
    fi

#     # user shoud provide sasldb2 file in ${SUBM_SASL_DB_FILE}
#     if [ ! -f "${SUBM_SASL_DB_FILE}" ] && [ -n "${SUBM_SASL_PASSWORD}" ]; then
#         echo "generate sasl db file from provided password .."
#         mkdir -p "$(dirname ${SUBM_SASL_DB_FILE})"
#         echo -n "${SUBM_SASL_PASSWORD}" | saslpasswd2 -f "${SUBM_SASL_DB_FILE}" -c -u "${POSTFIX_DOMAIN}" "${SUBM_SASL_USERNAME}"
#     fi
#     chmod 400 "${SUBM_SASL_DB_FILE}"
#     chown postfix:postfix "${SUBM_SASL_DB_FILE}"

    # in master.cf
    if [ -z "${SUBM_PORT}" ] || [ "$SUBM_PORT" == "587" ]; then
        SUBM_PORT=submission
    fi
    cat <<EOF >> ${POSTFIX_DIR}/master.cf
${SUBM_PORT}    inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_relay_restrictions=${SUBM_RELAY_RESTRICTIONS}
  -o smtpd_reject_unlisted_recipient=${SUBM_REJECT_UNLISTED_RECIPIENT}
  -o smtpd_tls_security_level=${SUBM_TLS_SECURITY_LEVEL}
  -o smtpd_tls_cert_file=${SUBM_TLS_CERT_FILE}
  -o smtpd_tls_key_file=${SUBM_TLS_KEY_FILE}
  -o smtpd_sasl_auth_enable=${SUBM_SASL_AUTH}
  -o milter_macro_daemon_name=ORIGINATING
EOF

fi

# smtp config
cat <<EOF >>${POSTFIX_DIR}/main.cf

# smtp settings
smtp_tls_security_level = ${SMTP_TLS_SECURITY_LEVEL}
EOF

# run postfix
exec postfix start-fg

# # tail logs to stderr
# exec tail -f /var/log/maillog >&2

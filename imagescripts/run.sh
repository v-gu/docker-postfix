#!/usr/bin/env bash

# init vars
POSTFIX_DIR="${POSTFIX_DIR}"
POSTSRSD_DIR="${POSTSRSD_DIR}"
OPENDKIM_DIR="${OPENDKIM_DIR}"
SASL2_DIR="${SASL2_DIR}"
SASLDB_PATH="${SASLDB_PATH}"

POSTFIX_HOSTNAME="${POSTFIX_HOSTNAME}"
POSTFIX_DOMAIN="${POSTFIX_DOMAIN:-${POSTFIX_HOSTNAME}}"
POSTFIX_ORIGIN="${POSTFIX_ORIGIN:-${POSTFIX_HOSTNAME}}"

# smtp input service
SMTPD_PORT="${SMTPD_PORT:-smtp}"
SMTPD_USE_SUBMISSION="${SMTPD_USE_SUBMISSION:-no}"
SMTPD_SUBM_PORT="${SMTPD_SUBM_PORT:-submission}"
SMTPD_SUBM_TLS_SECURITY_LEVEL="${SMTPD_SUBM_TLS_SECURITY_LEVEL:-may}"
SMTPD_SUBM_TLS_CERT_FILE="${SMTPD_SUBM_TLS_CERT_FILE}"
SMTPD_SUBM_TLS_KEY_FILE="${SMTPD_SUBM_TLS_KEY_FILE}"
SMTPD_SUBM_SASL_AUTH="${SMTPD_SUBM_SASL_AUTH:no}"
SMTPD_SUBM_REJECT_UNLISTED_RECIPIENT="${SMTPD_REJECT_UNLISTED_RECIPIENT:-no}"
SMTPD_SUBM_RELAY_RESTRICTIONS="${SMTPD_RELAY_RESTRICTIONS:-permit_sasl_authenticated,reject}"

# DKIM
DKIM_LISTEN_ADDR="${DKIM_LISTEN_ADDR:-127.0.0.1}"
DKIM_LISTEN_PORT="${DKIM_LISTEN_PORT:-9901}"
DKIM_DOMAIN="${DKIM_DOMAIN:-${POSTFIX_DOMAIN}}"
DKIM_SELECTOR="${DKIM_SELECTOR:-mail}"
DKIM_KEY_FILE="${DKIM_KEY_FILE:-/etc/opendkim.d/${DKIM_SELECTOR}.private}"
DKIM_TRUSTED_HOSTS="${DKIM_TRUSTED_HOSTS:-127.0.0.1\n::1\nlocalhost\n\n\*.example.com}"

USE_POSTSRSD="${USE_POSTSRSD:-no}"
POSTFIX_VA_DOMAINS="${POSTFIX_VA_DOMAINS:-${POSTFIX_DOMAIN}}"
POSTFIX_VA_MAPS="${POSTFIX_VA_MAPS}"
POSTFIX_TRANSPORTS="${POSTFIX_TRANSPORTS}"
SRS_LISTEN_ADDR="${SRS_LISTEN_ADDR:-127.0.0.1}"
SRS_DOMAIN="${SRS_DOMAIN:-${POSTFIX_DOMAIN}}"
SRS_FORWARD_PORT="${SRS_FORWARD_PORT:-10001}"
SRS_REVERSE_PORT="${SRS_REVERSE_PORT:-10002}"
SRS_SEPARATOR="${SRS_SEPARATOR:-=}"
SRS_TIMEOUT="${SRS_TIMEOUT:-1800}"
SRS_SECRET="${SRS_SECRET:-${POSTSRSD_DIR}/postsrsd.secret}"
SRS_PID_FILE="${SRS_PID_FILE}"
SRS_RUN_AS="${SRS_RUN_AS}"
SRS_CHROOT="${SRS_CHROOT}"
SRS_EXCLUDE_DOMAINS="${SRS_EXCLUDE_DOMAINS}"
SRS_REWRITE_HASH_LEN="${SRS_REWRITE_HASH_LEN:-4}"
SRS_VALIDATE_HASH_MINLEN="${SRS_VALIDATE_HASH_MINLEN:-4}"

# smtp output service
SMTP_SASL_AUTH_ENABLE="${SMTP_SASL_AUTH_ENABLE:-no}"
SMTP_TLS_SECURITY_LEVEL="${SMTP_TLS_SECURITY_LEVEL:-encrypt}"
SMTP_SASL_SECURITY_OPTIONS="${SMTP_SASL_SECURITY_OPTIONS:-noanonymous}"
SMTP_SASL_TLS_SECURITY_OPTIONS="${SMTP_SASL_TLS_SECURITY_OPTIONS:-noanonymous}"
SMTP_SASL_PASSWORD_MAPS="${SMTP_SASL_PASSWORD_MAPS:-hash:/etc/postfix/sasl_passwd}"
SMTP_RELAYHOST="${SMTP_RELAYHOST}"

# preparing app directories
ln -sn /etc/postfix ${POSTFIX_DIR}
ln -sn /etc/postsrsd ${POSTSRSD_DIR}
ln -sn /etc/opendkim ${OPENDKIM_DIR}

# start rsyslogd
rsyslogd

# init postfix
## init master.cf
if [ -z "${POSTFIX_SMTP_PORT+x}" -o "$POSTFIX_SMTP_PORT" == "25" ]; then
    POSTFIX_SMTP_PORT=smtp
fi
cat <<EOF > ${POSTFIX_DIR}/master.cf
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

## init main.cf
cat <<EOF >${POSTFIX_DIR}/main.cf
myhostname = ${POSTFIX_HOSTNAME}
mydomain = ${POSTFIX_DOMAIN}
myorigin = ${POSTFIX_ORIGIN}
virtual_alias_domains = ${POSTFIX_VA_DOMAINS}
virtual_alias_maps = hash:${POSTFIX_DIR}/virtual
transport_maps = hash:${POSTFIX_DIR}/transport

# Milter settings.
milter_protocol = 2
milter_default_action = accept
# OpenDKIM runs on port ${DKIM_LISTEN_ADDR}:${DKIM_LISTEN_PORT}.
smtpd_milters = inet:${DKIM_LISTEN_ADDR}:${DKIM_LISTEN_PORT}
non_smtpd_milters = inet:${DKIM_LISTEN_ADDR}:${DKIM_LISTEN_PORT}

# Other settings.
header_size_limit = 4096000
EOF

# add submission configs if required
if [ "${USE_SUBMISSION}" == 'yes' ]; then
    if [ -z "${POSTFIX_SUBM_PORT+x}" -o "$POSTFIX_SUBM_PORT" == "587" ]; then
        POSTFIX_SUBM_PORT=submission
    fi

    # add submission to postfix's master.cf
    cat <<EOF >> ${POSTFIX_DIR}/master.cf
${POSTFIX_SUBM_PORT}    inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=${SMTPD_SUBM_TLS_SECURITY_LEVEL}
  -o smtpd_tls_cert_file=${SMTPD_SUBM_TLS_CERT_FILE}
  -o smtpd_tls_key_file=${SMTPD_SUBM_TLS_KEY_FILE}
  -o smtpd_sasl_auth_enable=${SMTPD_SUBM_SASL_AUTH}
  -o smtpd_reject_unlisted_recipient=${SMTPD_SUBM_REJECT_UNLISTED_RECIPIENT}
  -o smtpd_relay_restrictions=${SMTPD_SUBM_RELAY_RESTRICTIONS}
  -o milter_macro_daemon_name=ORIGINATING
EOF

    # make sasl2 config
    mkdir -p ${SASL2_DIR} && mkdir -p ${SASLDB_PATH} && \
        cat <<EOF >${SASL2_DIR}/smtpd.conf
sasldb_path: ${SASLDB_PATH}
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
log_level: 7
EOF
    ln -s ${SASL2_DIR}/smtpd.conf /usr/lib/sasl2/smtpd.conf

    # add opendkim config
    cat <<EOF > ${OPENDKIM_DIR}/opendkim.conf
# OpenDKIM config.

# Log to syslog
BaseDirectory           ${OPENDKIM_DIR}

Syslog                  yes
SyslogSuccess           yes
LogWhy                  yes
# Required to use local socket with MTAs that access the socket as a non-
# privileged user (e.g. Postfix)
UMask                   002

Mode                    sv
PidFile                 ${OPENDKIM_DIR}/opendkim.pid
UserID                  root:root
Socket                  inet:${DKIM_LISTEN_PORT}@${DKIM_LISTEN_ADDR}

Canonicalization        relaxed/simple
SignatureAlgorithm      rsa-sha256

# Sign for example.com with key in /etc/opendkim.d/mail.private using
# selector 'mail' (e.g. mail._domainkey.example.com)
Domain                  ${DKIM_DOMAIN}
KeyFile                 ${DKIM_KEY_FILE}
Selector                ${DKIM_SELECTOR}

ExternalIgnoreList      refile:${OPENDKIM_DIR}/TrustedHosts
InternalHosts           refile:${OPENDKIM_DIR}/TrustedHosts
EOF

    echo -e "${DKIM_TRUSTED_HOSTS}" > ${OPENDKIM_DIR}/TrustedHosts

    # start opendkim server
    opendkim
fi

#add SRS configs if required
if [ "${USE_POSTSRSD}" == 'yes' ]; then
    cat <<EOF >> ${POSTFIX_DIR}/main.cf
sender_canonical_maps = tcp:localhost:${SRS_FORWARD_PORT}
sender_canonical_classes = envelope_sender
recipient_canonical_maps = tcp:localhost:${SRS_REVERSE_PORT}
recipient_canonical_classes= envelope_recipient,header_recipient
EOF

    # add virtual entries
    echo -e "$POSTFIX_VA_MAPS" > ${POSTFIX_DIR}/virtual
    postmap ${POSTFIX_DIR}/virtual
    rm ${POSTFIX_DIR}/virtual

    # add transport entries
    echo -e "$POSTFIX_TRANSPORTS" > ${POSTFIX_DIR}/transport
    postmap ${POSTFIX_DIR}/transport
    rm ${POSTFIX_DIR}/transport

    # prepare postsrsd
    echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > "${SRS_SECRET}"

    # run postsrsd
    cmd="postsrsd -D"
    # if [ -n "${SRS_LISTEN_ADDR+x}" ]; then
    #     cmd+=" -l ${SRS_LISTEN_ADDR}"
    # fi
    if [ -n "${SRS_DOMAIN}" ]; then
        cmd+=" -d ${SRS_DOMAIN}"
    fi
    if [ -n "${SRS_SEPARATOR}" ]; then
        cmd+=" -a ${SRS_SEPARATOR}"
    fi
    if [ -n "${SRS_FORWARD_PORT}" ]; then
        cmd+=" -f ${SRS_FORWARD_PORT}"
    fi
    if [ -n "${SRS_REVERSE_PORT}" ]; then
        cmd+=" -r ${SRS_REVERSE_PORT}"
    fi
    if [ -n "${SRS_TIMEOUT}" ]; then
        cmd+=" -t ${SRS_TIMEOUT}"
    fi
    if [ -n "${SRS_SECRET}" ]; then
        cmd+=" -s ${SRS_SECRET}"
    fi
    if [ -n "${SRS_PID_FILE}" ]; then
        cmd+=" -p ${SRS_PID_FILE}"
    fi
    if [ -n "${SRS_RUN_AS}" ]; then
        cmd+=" -u ${SRS_RUN_AS}"
    fi
    if [ -n "${SRS_CHROOT}" ]; then
        cmd+=" -c ${SRS_CHROOT}"
    fi
    if [ -n "${SRS_EXCLUDE_DOMAINS}" ]; then
        cmd+=" -X ${SRS_EXCLUDE_DOMAINS}"
    fi
    # if [ -n "${SRS_REWRITE_HASH_LEN+x}" ]; then
    #     cmd+=" -n ${SRS_REWRITE_HASH_LEN}"
    # fi
    # if [ -n "${SRS_VALIDATE_HASH_MINLEN+x}" ]; then
    #     cmd+=" -N ${SRS_VALIDATE_HASH_MINLEN}"
    # fi
    eval "${cmd}"
fi

## handle smtp output config
if [ "${SMTP_SASL_AUTH_ENABLE}" == "yes" ]; then
    cat <<EOF >>${POSTFIX_DIR}/main.cf

smtp_sasl_auth_enable = ${SMTP_SASL_AUTH_ENABLE}
smtp_tls_security_level = ${SMTP_TLS_SECURITY_LEVEL}
smtp_sasl_security_options = ${SMTP_SASL_SECURITY_OPTIONS}
smtp_sasl_tls_security_options = ${SMTP_SASL_TLS_SECURITY_OPTIONS}
EOF
fi

## handle relayhost
if [ -n "${SMTP_RELAYHOST}" ]; then
    cat <<EOF >>${POSTFIX_DIR}/main.cf

relayhost = ${SMTP_RELAYHOST}
EOF
fi

# run postfix
postfix start

# tail logs to stderr
exec tail -f /var/log/maillog >&2

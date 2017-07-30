#!/usr/bin/env bash

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
  -o smtpd_tls_security_level=may
  -o smtpd_tls_cert_file=${POSTFIX_SMTP_TLS_CERT_FILE}
  -o smtpd_tls_key_file=${POSTFIX_SMTP_TLS_KEY_FILE}
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF

    # make sasl2 config
    mkdir -p ${SASL2_DIR} && \
        cat <<EOF >${SASL2_DIR}/smtpd.conf
sasldb_path: ${SASLDB_PATH}
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
log_level: 7
EOF
    ln -s ${SASL2_DIR}/smtpd.conf /usr/lib/sasl2/smtpd.conf
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

    # add transport entries
    echo -e "$POSTFIX_TRANSPORTS" > ${POSTFIX_DIR}/transport
    postmap ${POSTFIX_DIR}/transport

    # prepare postsrsd
    echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) > "${SRS_SECRET}"

    # run postsrsd
    cmd="postsrsd -D"
    if [ -n "${SRS_LISTEN_ADDR+x}" ]; then
        cmd+=" -l ${SRS_LISTEN_ADDR}"
    fi
    if [ -n "${SRS_DOMAIN+x}" ]; then
        cmd+=" -d ${SRS_DOMAIN}"
    fi
    if [ -n "${SRS_SEPARATOR+x}" ]; then
        cmd+=" -a ${SRS_SEPARATOR}"
    fi
    if [ -n "${SRS_FORWARD_PORT+x}" ]; then
        cmd+=" -f ${SRS_FORWARD_PORT}"
    fi
    if [ -n "${SRS_REVERSE_PORT+x}" ]; then
        cmd+=" -r ${SRS_REVERSE_PORT}"
    fi
    if [ -n "${SRS_TIMEOUT+x}" ]; then
        cmd+=" -t ${SRS_TIMEOUT}"
    fi
    if [ -n "${SRS_SECRET+x}" ]; then
        cmd+=" -s ${SRS_SECRET}"
    fi
    if [ -n "${SRS_PID_FILE+x}" ]; then
        cmd+=" -p ${SRS_PID_FILE}"
    fi
    if [ -n "${SRS_RUN_AS+x}" ]; then
        cmd+=" -u ${SRS_RUN_AS}"
    fi
    if [ -n "${SRS_CHROOT+x}" ]; then
        cmd+=" -c ${SRS_CHROOT}"
    fi
    if [ -n "${SRS_EXCLUDE_DOMAINS+x}" ]; then
        cmd+=" -X ${SRS_EXCLUDE_DOMAINS}"
    fi
    if [ -n "${SRS_REWRITE_HASH_LEN+x}" ]; then
        cmd+=" -n ${SRS_REWRITE_HASH_LEN}"
    fi
    if [ -n "${SRS_VALIDATE_HASH_MINLEN+x}" ]; then
        cmd+=" -N ${SRS_VALIDATE_HASH_MINLEN}"
    fi
    eval "${cmd}"
fi

# run postfix
postfix start

# tail logs to stderr
exec tail -f /var/log/maillog >&2

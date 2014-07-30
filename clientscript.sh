yum -y install openldap-clients sssd libsss_sudo

cat >> /etc/hosts << EOF
10.0.1.33 ldap.test.com
EOF

mkdir /etc/openldap/cacerts

if [ ! -f /etc/pki/tls/certs/centos.cert ];
then
    scp root@10.0.1.33:/etc/pki/tls/certs/centos.cert /etc/openldap/cacerts/centos.cert
fi

if [ ! -f /etc/pki/tls/certs/centos.key ];
then
    scp root@10.0.1.33:/etc/pki/tls/certs/centos.key /etc/openldap/cacerts/centos.key
fi

/usr/sbin/cacertdir_rehash /etc/openldap/cacerts
chown -Rf root:500 /etc/openldap/cacerts
chmod -Rf 750 /etc/openldap/cacerts
restorecon -R /etc/openldap/cacerts

authconfig-tui

authconfig --enablemkhomedir --updateall

sed -i '/\[pam\]/a offline_credentials_expiration=5' /etc/sssd/sssd.conf
cat >> /etc/sssd/sssd.conf << EOF
# Enumeration means that the entire set of available users and groups on the
# remote source is cached on the local machine. When enumeration is disabled,
# users and groups are only cached as they are requested.
enumerate=true

# Configure client certificate auth.
ldap_tls_cert = /etc/openldap/cacerts/client.cert
ldap_tls_key = /etc/openldap/cacerts/client.key
ldap_tls_reqcert = demand
EOF

sed -i -e 's/services = nss, pam/services = nss, pam, sudo/g' /etc/sssd/sssd.conf
# Restart sssd
service sssd restart

# Start sssd after reboot.
chkconfig sssd on

sed -i '/^sudoers.*/d' /etc/nsswitch.conf
cat >> /etc/nsswitch.conf << EOF
sudoers: sss files
EOF


sed -i '/^sudoers_base.*\|^binddn.*\|^bindpw.*\|^ssl on.*\|^tls_cert.*\|^tls_key.*\|sudoers_debug.*/d' /etc/openldap/ldap.conf
cat >> /etc/openldap/ldap.conf << EOF
# Configure sudo ldap.
uri ldap://ldap.test.com
base dc=test,dc=com
sudoers_base ou=SUDOers,dc=test,dc=com
ssl on
tls_cacertdir /etc/openldap/cacerts
sudoers_debug 5
EOF    
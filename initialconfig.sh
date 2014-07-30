setenforce 1
setsebool -P domain_kernel_load_modules 1

cat >> /etc/hosts << EOF
10.0.1.33 ldap.test.com
EOF

# Create folder to store log files in
mkdir /var/log/slapd
chmod 755 /var/log/slapd/
chown ldap:ldap /var/log/slapd/

# Redirect all log files through rsyslog.
sed -i "/local4.*/d" /etc/rsyslog.conf
cat >> /etc/rsyslog.conf << EOF
local4.*                        /var/log/slapd/slapd.log
EOF
service rsyslog restart


iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 389 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 636 -j ACCEPT

service iptables save

yum -y install openldap-servers migrationtools

openssl req -new -x509 -nodes -out /etc/pki/tls/certs/centos.cert -keyout /etc/pki/tls/certs/centos.key -days 365

chown -R root:ldap /etc/pki/tls/certs/centos.*

sed -i -e 's/my-domain/test/g' /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}bdb.ldif

sed -i -e 's/my-domain/test/g' /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{1\}monitor.ldif

sed -i -e 's/manager/Manager/g' /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{1\}monitor.ldif

echo "olcRootPW: `slappasswd -s password`" >> /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}bdb.ldif

sed -i -e 's/olcRootDN: cn=config/olcRootDN: cn=admin,cn=config/g' /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{0\}config.ldif

echo "olcRootPW: `slappasswd -s password`" >> /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{0\}config.ldif

echo "olcTLSCertificateFile: /etc/pki/tls/certs/centos.cert" >> /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}bdb.ldif

echo "olcTLSCertificateKeyFile: /etc/pki/tls/certs/centos.key" >> /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}bdb.ldif

cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG

sed -i -e 's/LDAPS=no/LDAPS=yes/g' /etc/sysconfig/ldap

chkconfig slapd on

service slapd start

/bin/cp -f  /usr/share/doc/sudo-1.8.6p3/schema.OpenLDAP /etc/openldap/schema/sudo.schema
restorecon /etc/openldap/schema/sudo.schema

echo "olcAccess: {0}to dn.subtree='ou=people,dc=test,dc=com' attrs=userPassword by self write by anonymous auth by * none" >> /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}bdb.ldif
echo "olcAccess: {1}to * by self write by * read" >> /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}bdb.ldif

# Create a conversion file for schema
mkdir ~/sudoWork
echo "include /etc/openldap/schema/sudo.schema" > ~/sudoWork/sudoSchema.conf
# Convert the "Schema" to "LDIF".
slapcat -f ~/sudoWork/sudoSchema.conf -F /tmp/ -n0 -s "cn={0}sudo,cn=schema,cn=config" > ~/sudoWork/sudo.ldif
# Remove invalid data.
sed -i "s/{0}sudo/sudo/g" ~/sudoWork/sudo.ldif
# Remove last 8 (invalid) lines.
head -n-8 ~/sudoWork/sudo.ldif > ~/sudoWork/sudo2.ldif
# Load the schema into the LDAP server
ldapadd -H ldap:/// -x -D "cn=admin,cn=config" -W -f ~/sudoWork/sudo2.ldif
ldapadd -H ldap:/// -x -D "cn=admin,cn=config" -W << EOF
dn: cn=module{0},cn=config
objectClass: olcModuleList
cn: module{0}
olcModulePath: /usr/lib/openldap/
EOF
ldapadd -H ldap:/// -x -D "cn=admin,cn=config" -W << EOF
dn: cn=module{0},cn=config
changetype:modify
add: olcModuleLoad
olcModuleLoad: auditlog.la

dn: olcOverlay=auditlog,olcDatabase={2}bdb,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcAuditLogConfig
olcOverlay: auditlog
olcAuditlogFile: /var/log/slapd/auditlog.log
EOF
ldapadd -H ldap:/// -x -D "cn=admin,cn=config" -W << EOF
dn: cn=module{0},cn=config
changetype:modify
add: olcModuleLoad
olcModuleLoad: ppolicy.la

dn: olcOverlay=ppolicy,olcDatabase={2}bdb,cn=config
olcOverlay: ppolicy
objectClass: olcOverlayConfig
objectClass: olcPPolicyConfig
olcPPolicyHashCleartext: TRUE
olcPPolicyUseLockout: TRUE
olcPPolicyDefault: cn=default,ou=pwpolicies,dc=test,dc=com
EOF

ldapadd  -H ldap:/// -x -D "cn=Manager,dc=test,dc=com" -W -f database.ldif
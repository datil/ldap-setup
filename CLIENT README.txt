Please change IP address in the script to your LDAP Server's ip where necessary.

The script will run authconfig which provides a simple method to configure the pam modules.
When the windows pops up configure as follow.
Enable the following options:
                  Under User Information: Use LDAP
                  Under Authentication: Use MD5 Passwords, Use Shadow Passwords, Use LDAP Authentication, Local authorization is sufficient.
Choose next.
                   Enable: Use TLS
Set ldap server, use the servers defined hostname, NOT the ip address.Example: ldap://ldap.test.com.
Base DN: set the DN in which the client will look for the users. for example dc=test,dc=com
No more human input is needed for the rest of the script.
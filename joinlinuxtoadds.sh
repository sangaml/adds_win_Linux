#!/bin/bash
hostnamectl set-hostname linuxvm
echo "127.0.0.1  linuxvm sangamlonkar14.cf" > /etc/hosts
apt-get update -y
export DEBIAN_FRONTEND=noninteractive
apt-get install -y krb5-user 
apt-get install samba sssd sssd-tools libnss-sss libpam-sss ntp ntpdate realmd adcli -y
sed -i '/default_realm/c\            default_realm = SANGAMLONKAR14.CF' /etc/krb5.conf
realm discover SANGAMLONKAR14.CF
echo "Lkjhg5fdsa@" | kinit pradnesh@SANGAMLONKAR14.CF
echo "Lkjhg5fdsa@" | realm join --verbose SANGAMLONKAR14.CF -U 'pradnesh@SANGAMLONKAR14.CF' --install=/
sed -e '/use_fully/ s/^#*/#/' -i /etc/sssd/sssd.conf
echo "ldap_user_principal = nosuchattribute" /etc/sssd/sssd.conf
service sssd restart
echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" >> /etc/pam.d/common-session

#!/bin/bash

#
# CentOS and RHEL 7 use NetworkManager. Add a script to be automatically invoked when interface comes up.
#
# NetworkManager Dispatch script
# Deployed by Cloudera Director Bootstrap
#
# Expected arguments:
#    $1 - interface
#    $2 - action
#
# See for info: http://linux.die.net/man/8/networkmanager

# Register A and PTR records when interface comes up
# only execute on the primary nic
##if [ "$1" != "eth0" ] || [ "$2" != "up" ]
##then
##    exit 0;
##fi

# when we have a new IP, perform nsupdate
new_ip_address=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')

host=$(hostname -s)
domain=$(nslookup $(grep -i nameserver /etc/resolv.conf | cut -d ' ' -f 2) | grep -i name | cut -d ' ' -f 3 | cut -d '.' -f 2- | rev | cut -c 2- | rev)
IFS='.' read -ra ipparts <<< "$new_ip_address"
ptrrec="$(printf %s "$new_ip_address." | tac -s.)in-addr.arpa"
nsupdatecmds=$(mktemp -t nsupdate.XXXXXXXXXX)
resolvconfupdate=$(mktemp -t resolvconfupdate.XXXXXXXXXX)
echo updating resolv.conf
grep -iv "search" /etc/resolv.conf > "$resolvconfupdate"
echo "search $domain" >> "$resolvconfupdate"
cat "$resolvconfupdate" > /etc/resolv.conf
echo "Attempting to register $host.$domain and $ptrrec"
{
    echo "update delete $host.$domain a"
    echo "update add $host.$domain 600 a $new_ip_address"
    echo "send"
    echo "update delete $ptrrec ptr"
    echo "update add $ptrrec 600 ptr $host.$domain"
    echo "send"
} > "$nsupdatecmds"
nsupdate "$nsupdatecmds"
exit 0;
EOF
chmod 755 /etc/NetworkManager/dispatcher.d/12-register-dns
service network restart
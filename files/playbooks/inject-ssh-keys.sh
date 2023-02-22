#!/bin/bash
set -eux

mkdir -p /var/ssh
chmod 0644 /var/ssh
for I in "$privkey" upstream_gerrit_key rdo_gerrit_key; do
    set +x
    key_cmd="echo \$$I | base64 -d | tee /var/ssh/$I"
    eval $key_cmd > /dev/null
    set -x
    # add trailing line break required for the key file to be vaild. it gets
    # eaten in the base64 conversion along the way
    echo >> /var/ssh/$I
    chmod 0600 /var/ssh/$I
done
ssh-keygen -y -f "/var/ssh/$privkey" > "/var/ssh/$privkey.pub"
chmod 0600 "/var/ssh/$privkey.pub"
echo "Keys were injected"

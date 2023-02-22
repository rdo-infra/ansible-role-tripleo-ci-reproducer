#!/bin/bash
set -ex

mkdir -p /var/ssh
chmod 0644 /var/ssh
for I in user_pri_key user_pub_key upstream_gerrit_key rdo_gerrit_key; do
    set +x
    key_cmd="echo \$$I | base64 -d | tee /var/ssh/$I"
    eval $key_cmd > /dev/null
    set -x
    # add trailing line break required for the key file to be vaild. it gets
    # eaten in the base64 conversion along the way
    echo >> /var/ssh/$I
    chmod 0600 /var/ssh/$I
done

mv -f /var/ssh/user_pri_key "/var/ssh/$user_pri_key_name"
if [ "$user_pri_key_name" == "id_rsa" ]; then
  ssh-keygen -y -f "/var/ssh/$user_pri_key_name" > "/var/ssh/$user_pub_key_name"
  chmod 0600 "/var/ssh/$user_pub_key_name"
else
  mv -f /var/ssh/user_pub_key /var/ssh/$user_pub_key_name
fi
echo "Keys were injected"

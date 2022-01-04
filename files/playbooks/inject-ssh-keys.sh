#/bin/bash
set -ex
printenv

mkdir -p /var/ssh
chmod 0644 /var/ssh
for I in id_rsa upstream_gerrit_key rdo_gerrit_key; do
    key_cmd="echo \$$I | base64 -d | tee /var/ssh/$I"
    eval $key_cmd
    # add trailing line break required for the key file to be vaild. it gets
    # eaten in the base64 conversion along the way
    echo >> /var/ssh/$I
    chmod 0600 /var/ssh/$I
    cat /var/ssh/$I
done
ssh-keygen -y -f /var/ssh/id_rsa > /var/ssh/id_rsa.pub
chmod 0600 /var/ssh/id_rsa.pub

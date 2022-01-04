#!/bin/bash
set -ex

mkdir -p ~/.ssh
chmod 0700 ~/.ssh
for HOST in review.opendev.org review.rdoproject.org gerrit; do
    ssh-keyscan -t rsa -p 29418 $HOST >> ~/.ssh/known_hosts
done

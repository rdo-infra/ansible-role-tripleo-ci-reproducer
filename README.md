ci-reproducer
===================

An Ansible role to start a CI zuul + gerrit environment to test jobs and
patches at an openstack tenant or a ready provisioned VMs like libvirt.

Requirements
------------

* [docker](https://docs.docker.com/install/)
* [openstack auth config at clouds.yaml](https://docs.openstack.org/python-openstackclient/pike/configuration/index.html)
* [centos-7 and fedora-28 images](https://nb02.openstack.org/images/)
* [virt-edit to inject pub keys to images](https://docs.openstack.org/image-guide/modify-images.html)
* Sudo permissions

Role Variables
--------------

* `os_cloud_name` -- openstack cloud to use, it has to be defined at
  clouds.yaml
* `os_centos7_image` -- Image to use at centos-7 nodesets,
  default value is penstack-infra-centos-7
* `os_fedora28_image` -- Image to use at fedora-28 nodesets,
  default value is penstack-infra-centos-7
* `upstream_gerrit_user` -- User clone repos from review.opendev.org,
* `rdo_gerrit_user` -- User clone repos from review.rdoproject.org,
  default value is ansible_user
* `install_path` -- Path to install reproducer, after installation
  is possible to play with docker-compose commands for more advanced uses,
  default is ansible_user_dir/tripleo-ci-reproducer/
* `state` -- Action to do 'present' to start 'absent' to stop.
* `tripleo_ci_gerrit_key` -- ssh key for the tripleo ci gerrit user if present
  it will be encrypted after zuul starts to be able to run the reproducer
  job tripleo-ci-reproducer-fedora-28
* `build_zuul` and `build_nodepool` -- Point to a zuul/nodepool version to use
  with 'version' and 'refspec' example:
       build_zuul:
          version: FETCH_HEAD
          refspec: refs/changes/77/607077/1
       build_nodepool:
          version: HEAD
          refspec: refs/for/master
* `nodepool_provider` -- Type of nodepool provider to use, it has three
  possible values:
  - openstack: Use an openstack tenant
  - host: Use the host where docker-compose runs
  - libvirt: Start up a pair of libvirt nodes at install and connects nodepool
    to it
* `zuul_job` -- zuul job to executo
* `zuul_yaml` -- zuul config to run it overwrite zuul_job
* `depends_on` -- Gerrit reviews to test
* `user_pri_key` -- ssh private key to use for the user, default "id_rsa"
* `user_pub_key` -- ssh public key to use for the user, default "id_rsa.pub"
* `ssh_path` --  path where the ssh keys are present, default "~/.ssh"
* `launch_job_branch` -- branch to launch the job from, default "master"

Prerequisites
-------------
Inside the role there is a playbook to prepare your machine to run the
reproducer, the path is playbooks/tripleo-ci-reproducer/pre.yaml is also
running at CI so it's well tested.

Example Playbook
----------------

Run standalone job over tripleo noop change

```yaml
---
- name: Start reproducer
  hosts: virthost
  vars:
    zuul_job: tripleo-ci-centos-7-standalone
    depends_on:
        - https://review.opendev.org/#/c/622261/
  tasks:
    - include_role:
        name: ci-reproducer
```

Run standalone without tempest towards a noop change
```yaml
---
- name: Stop reproducer
  hosts: virthost
  vars:
    zuul_yaml:
      - project:
          check:
            jobs:
              - name: tripleo-ci-centos-7-standalone
                vars:
                  override_settings:
                    tempest_run: false
  tasks:
    - include_role:
        name: ci-reproducer
    - ci-reproducer
```
Run standalone job over stable/rocky

```yaml
---
- name: Start reproducer
  hosts: virthost
  vars:
    zuul_job: tripleo-ci-centos-7-standalone
    launch_job_branch: stable/rocky
  tasks:
    - include_role:
        name: ci-reproducer
```


License
-------

Apache

Author Information
------------------

Openstack Tripleo CI Team

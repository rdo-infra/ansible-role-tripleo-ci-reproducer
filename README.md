TripleO CI Reproducer
===================

An Ansible role to start a CI zuul + gerrit environment to test jobs and
patches at an openstack tenant or a ready provisioned VMs like libvirt.

- [TripleO CI Reproducer](#tripleo-ci-reproducer)
  - [Requirements](#requirements)
  - [Install](#install)
  - [Tenant Configuration](#tenant-configuration)
  - [Setup Playbook](#setup-playbook)
  - [Role Variables](#role-variables)
  - [Example Playbook](#example-playbook)
  - [Testing trusted repository changes](#testing-trusted-repository-changes)
  - [License](#license)
  - [Author Information](#author-information)

Requirements
------------

Packages:

- ansible
- docker/docker-compose (CentOS7)
  - [docker-ce](https://docs.docker.com/engine/install/) (CentOS8/Fedora)
- podman (CentOS8/Fedora)

System:

- [openstack auth config at clouds.yaml](#tenant-configuration)
- [centos/fedora images](https://nb02.opendev.org/images/)
- [virt-edit to inject pub keys to images](https://docs.openstack.org/image-guide/modify-images.html)
- Sudo permissions

Install
-------

TripleO CI Reproducer can be installed in your local environment or any remote
server. A typical setup includes local installations of Zuul, Nodepool and
Gerrit. Follow these 3 steps to install:

  1. Install [package requirements](#requirements)
  2. Create ~/.config/openstack/clouds.yaml](#tenant-configuration)
  3. Run [setup.yml](#setup-playbook) playbook to set up reproducer tenant

```bash
ansible-playbook -vv setup.yml -e "upstream_gerrit_username=<your_upstream_gerrit_user> rdo_gerrit_username=<your_rdo_gerrit_user>"
```

Tenant Configuration
--------------------

~/.config/openstack/clouds.yaml

```yaml
clouds:
  rdo-cloud:
    identity_api_version: 3
    region_name: regionOne
    auth:
      auth_url: https://my.cloud.authurl.org:13000
      password: <my_password>
      project_name: <my_project_name>
      username:  <my_username>
      user_domain_name: Default
      project_domain_name: Default
```

Setup Playbook
--------------

```yaml
---
- name: Set up reproducer
  hosts: localhost
  tasks:

    - name: Set up reproducer
      include_role:
        name: "../ansible-role-tripleo-ci-reproducer"
      vars:
        upstream_gerrit_user: "{{ upstream_gerrit_username }}"
        rdo_gerrit_user: "{{ rdo_gerrit_username }}"
```

Role Variables
--------------

- `os_cloud_name` -- openstack cloud to use, it has to be defined at
  clouds.yaml
- `os_centos7_image` -- Image to use at centos-7 nodesets,
  default value is upstream-cloudinit-centos-7
- `os_centos8_image` -- Image to use at centos-8 nodesets,
  default value is upstream-cloudinit-centos-8
- `os_rhel8_image` -- Image to use at centos-8 nodesets,
  default value is upstream-cloudinit-rhel-8
- `os_centos9_image` -- Image to use at centos-9 nodesets,
  default value is upstream-cloudinit-centos-9
- `upstream_gerrit_user` -- User clone repos from review.opendev.org,
- `rdo_gerrit_user` -- User clone repos from review.rdoproject.org,
  default value is ansible_user
- `install_path` -- Path to install reproducer, after installation
  is possible to play with docker-compose commands for more advanced uses,
  default is ansible_user_dir/tripleo-ci-reproducer/
- `state` -- Action to do 'present' to start 'absent' to stop.
- `tripleo_ci_gerrit_key` -- ssh key for the tripleo ci gerrit user if present
  it will be encrypted after zuul starts to be able to run the reproducer
  job tripleo-ci-reproducer-fedora-28
- `build_zuul` and `build_nodepool` -- Point to a zuul/nodepool version to use
  with 'version' and 'refspec' example:
       build_zuul:
          version: FETCH_HEAD
          refspec: refs/changes/77/607077/1
       build_nodepool:
          version: HEAD
          refspec: refs/for/master
- `nodepool_provider` -- Type of nodepool provider to use, it has three
  possible values:
  - openstack: Use an openstack tenant
  - host: Use the host where docker-compose runs
  - libvirt: Start up a pair of libvirt nodes at install and connects nodepool
    to it
- `teardown` -- Bootstraps VMs for libvirt provider from a scratch (default).
   No snapshots will be carried on (until combined with `restore_snapshot`).
- `create_snapshot` -- snapshots libvirt VMs before configuring it for Nodepool
- `restore_snapshot` -- restores libvirt VMs from a snapshot. Zuul will be
   reconfigured after that, and restored nodes will be added into Nodepool. If
   combined with `teardown`, restored nodes will re-run preparations playbook
- `zuul_job` -- zuul job to executo
- `zuul_job_retries` --  wait time for zuul job to start, default "20"
- `zuul_yaml` -- zuul config to run it overwrite zuul_job
- `depends_on` -- Gerrit reviews to test
- `user_pri_key` -- ssh private key to use for the user, default "id_rsa"
- `user_pub_key` -- ssh public key to use for the user, default "id_rsa.pub"
- `ssh_path` --  path where the ssh keys are present, default "~/.ssh"
- `launch_job_branch` -- branch to launch the job from, default "master"
- `podman_pull` -- run podman pull on containers before launching the pod

Example Playbook
----------------

Run standalone job over tripleo noop change

```yaml
---
- name: Start reproducer
  hosts: virthost
  vars:
    zuul_job: tripleo-ci-centos-8-standalone
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
              - name: tripleo-ci-centos-8-standalone
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
    zuul_job: tripleo-ci-centos-8-standalone
    launch_job_branch: stable/rocky
  tasks:
    - include_role:
        name: ci-reproducer
```

Testing trusted repository changes
----------------------------------

When there is required to test change in trusted Zuul repository, the current
reproducer can be very useful.

Zuul repositories can be trusted and untrusted [1](#f1). Patches that affect
job with secrets submitted to trusted repository can not be tested prior to merge
because of security context.
That the place when Zuul reproducer comes into play.

In current reproducer code we install custom Gerrit that contains 2 test projects
``test1`` and ``test2`` and config project ``zuul-config``. ``zuul-config`` is
actual trusted config repository for our setup. It includes some base jobs (not
inherited from upstream) and all TripleO CI related code copied from upstream.

In file ``files/playbooks/add_rdo_config.yml`` you can see copying files and
directories from RDO config repo (``review.rdoproject.org-config``) to local
``zuul-config`` repository, while secrets are stripped [2](#f2). Eventually
we have in ``zuul-config`` repo all TripleO related code like periodic jobs,
playbooks, roles, etc etc. Now we can change them and test locally.

While we still can't run jobs on patch of config repository even if it's local,
we can just merge a patch to ``zuul-config`` and then run any job in ``test1``
repository which tests merged changes of ``zuul-config``.

For example the current workflow is recommended for testing ``ovb-manage`` role
in trusted repository of RDO:

After you set up reproducer with example playbook ``start.yaml`` in directory of
the reproducer:

```yaml
---
- name: Start reproducer
  hosts: localhost
  tasks:

    - name: Start reproducer
      include_role:
        name: "../ansible-role-tripleo-ci-reproducer"
      vars:
        upstream_gerrit_user: "{{ upstream_gerrit_username }}"
        rdo_gerrit_user: "{{ rdo_gerrit_username }}"
```

and installing it as:

```bash
ansible-playbook -vv setup.yml -e "upstream_gerrit_username=<your_upstream_gerrit_user> rdo_gerrit_username=<your_rdo_gerrit_user>"
```

you wait until the tenant is up and you can see ``http://localhost:9000/t/tripleo-ci-reproducer/status``
up.
Now clone the ``zuul-config`` repository:

```bash
git clone http://localhost:8080/zuul-config
```

enter ``zuul-config`` directory and make all required changed to ``roles/ovb-manage/``.
Commit and send to review:

```bash
git config --local gitreview.username "admin"
git commit -a -m "Change OVB manage role"
git review
```

while using ``admin`` as Gerrit username.

Afterwards we need to merge it. Let's enter Gerrit by opening in browset ``http://localhost:8080``.
Log in to Gerrit by clicking on ``Sign In`` and choose ``admin`` link on the sing-in page.
Now you can view your change in "My changes" of Gerrit. Go to it and approve it
by setting +2 and +Verified. After that you can click on button "Submit" and merge
your change.

All this Gerrit work can be done alternatively by git command like:

```bash
git push -f --set-upstream gerrit +HEAD:master
```

Update your local ``zuul-config`` to see that you have your changed code merged:

```bash
cd zuul-config && git pull
```

If everything is OK, let's run a real OVB job. Clone ``test1`` project:

```bash
git clone http://localhost:8080/test1
```

enter it and create a ``zuul.yaml`` file like that:

```bash
cd test1 && touch zuul.yaml
```

Let's populate ``zuul.yaml`` file with necessary config to run an OVB job:

```yaml
---
- project:
    check:
      jobs:
        - tripleo-ci-centos-8-ovb-3ctlr_1comp-featureset001-test

- job:
    name: tripleo-ci-centos-8-ovb-3ctlr_1comp-featureset001-test
    parent: tripleo-ci-centos-8-ovb-3ctlr_1comp-featureset001
    vars:
      cloud_secrets:
        rdocloud:
          username: <your_username_for_cloud>
          password: <your_password_for_cloud>
          project_name: <your_project_name_for_cloud>
          auth_url: https://rhos-d.infra.prod.upshift.rdu2.redhat.com:13000/v3
          region_name: regionOne
          identity_api_version: 3
          user_domain_name: redhat.com
      key_name: <your_keypair_for_cloud>
      cloud_settings:
        rdocloud:
          public_ip_net: provider_net_shared_3
          undercloud_flavor: m1.xlarge
          baremetal_flavor: m1.large
          bmc_flavor: m1.medium
          extra_node_flavor: m1.small
          baremetal_image: CentOS-8-x86_64-GenericCloud-released-latest
      remove_ovb_after_job: true # use false if you need to have all OVB nodes after a job
      force_job_failure: true # use true if you want job to fail in the end and stay for further investigations
      registry_login_enabled: false # use it to avoid login failures to RDO registry, login isn't required
      quickstart_verbosity: -vv # use it for more verbosity in quickstart logs
```

In case of PSI/Upshift clouds you will need to create a configuration in
local openstack client config in `~/.config/openstack/clouds.yaml`:

```yaml
clouds:
  rdocloud:
    identity_api_version: 3
    auth:
      auth_url: https://rhos-d.infra.prod.upshift.rdu2.redhat.com:13000/v3
      username: <your_username_for_cloud>
      password: <your_password_for_cloud>
      project_name: <your_project_name_for_cloud> # rhos-dfg-pcci
      project_domain_id: <your_project_domain_id_for_cloud> # 62cf1b5ec006489db99e2b0ebfb55f57
      user_domain_name: "redhat.com"
    regions:
    - name: regionOne
      values:
        networks:
         - name: provider_net_shared_3  # or whatever external network you want
           routes_externally: true
           nat_source: true
```

The job definition should look like:

```yaml
- job:
    name: tripleo-ci-centos-8-containers-multinode-test
    parent: tripleo-ci-centos-8-containers-multinode
    vars:
      environment_type: multinode-psi
      featureset_override:
        undercloud_undercloud_nameservers:
         - 10.11.5.19
         - 10.10.160.2
         - 10.5.30.160
         - 8.8.8.7
         - 8.8.8.8
        undercloud_undercloud_ntp_servers:
          - 10.5.26.10
          - clock.redhat.com
        undercloud_undercloud_debug: true
        # For the overcloud deploy command.
        ntp_server: '10.5.26.10,clock.redhat.com,clock2.redhat.com'
        mirror_fqdn: afs-mirror.sf.hosted.upshift.rdu2.redhat.com
      custom_nameserver:
         - 10.11.5.19
         - 10.10.160.2
         - 10.5.30.160
         - 8.8.8.7
         - 8.8.8.8
      external_net: provider_net_shared_3
```

In this case you can use any mirror which is available from PSI cloud, the local
`afs-mirror` or rdo-cloud/vexxhost/upstream mirror.
`external_net` should be one of available external networks in PSI cloud.

For OVB job it can be like:

```yaml
- job:
    name: tripleo-ci-centos-8-ovb-3ctlr_1comp-featureset001-test
    parent: tripleo-ci-centos-8-ovb-3ctlr_1comp-featureset001
    vars:
      cloudenv: internal
      mirror_fqdn: mirror.regionone.rdo-cloud.rdoproject.org # or afs-mirror.sf.hosted.upshift.rdu2.redhat.com
      custom_nameserver:
        - 10.5.30.160
        - 10.11.5.19
      undercloud_undercloud_nameservers:
        - 10.5.30.160
      external_net: provider_net_shared_3
      ntp_server: '10.5.26.10,clock.redhat.com,clock2.redhat.com'
      undercloud_undercloud_ntp_servers:
        - 10.5.26.10
        - clock.redhat.com
      cloud_secrets:
        rdocloud:
          username: <cloud_username>
          password: <cloud_password>
          project_name: rhos-dfg-pcci
          auth_url: https://rhos-d.infra.prod.upshift.rdu2.redhat.com:13000/v3
          region_name: regionOne
          identity_api_version: 3
          user_domain_name: redhat.com
          project_domain_id: "62cf1b5ec006489db99e2b0ebfb55f57"
      key_name: <your_key_name>
      cloud_settings:
        rdocloud:
          public_ip_net: provider_net_shared_3
          undercloud_flavor: m1.xlarge
          baremetal_flavor: m1.large
          bmc_flavor: m1.medium
          extra_node_flavor: m1.small
          baremetal_image: CentOS-8-x86_64-GenericCloud-released-latest
      remove_ovb_after_job: false # use false if you need to have all OVB nodes after a job
      force_job_failure: true # use true if you want job to fail in the end and stay for further investigations
      registry_login_enabled: false # use it to avoid login failures to RDO registry, login isn't required
      quickstart_verbosity: -vv
```

Because of multiple external networks in the cloud, it's important to choose one
and configure it in `clouds.yaml` as an external one. If you have a router in the
tenant and private network, the routers external gateway must be for the same
networks as in `clouds.yaml` (in this case for `provider_net_shared_3`).

We use secrets in zuul.yaml because we don't have in our ``zuul-config`` repository,
when we removed them a few steps ago.
Now just commit and push the change while using ``admin`` username:

```bash
git config --local gitreview.username "admin"
git add *
gc -am "Run OVB change on this job"
git review
```

Check your Zuul tenant for running job in ``http://localhost:9000/t/tripleo-ci-reproducer/status``.
You can open a console to see what is going on there, ``ssh`` to node, see logs of
``zuul-executor`` container, enable Zuul debug, etc etc. The current running OVB job
now uses code you changed in ``ovb-manage`` role before and you can test it and debug.

Don't forget to hold the node if you need it (nodepool node, for OVB it's ``remove_ovb_after_job`` parameter in ``zuul.yaml``)

```bash
docker-compose exec scheduler zuul autohold --tenant tripleo-ci-reproducer --job tripleo-ci-centos-8-ovb-3ctlr_1comp-featureset001-test --reason debug --project test1
```

Happy testing!

License
-------

Apache

Author Information
------------------

Openstack Tripleo CI Team

[1]: https://zuul-ci.org/docs/zuul/user/config.html#security-contexts "Security contexts"
[2]: Secrets from different Zuul system don't make sense, since they can't be decrypted by a different Zuul system.

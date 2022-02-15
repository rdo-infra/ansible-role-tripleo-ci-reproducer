TripleO CI Reproducer
=====================

An Ansible role to start a CI environment with Zuul and Gerrit to test patches and
run jobs on OpenStack compute instances or a preprovisioned libvirt domains.

- [TripleO CI Reproducer](#tripleo-ci-reproducer)
  - [Requirements](#requirements)
  - [Install](#install)
  - [OpenStack Project Configuration](#openstack-project-configuration)
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

- [OpenStack project configuration in `~/.config/openstack/clouds.yaml`](#openstack-project-configuration)
- [centos/fedora images](https://nb02.opendev.org/images/)
- [virt-edit to inject pub keys to images](https://docs.openstack.org/image-guide/modify-images.html)
- sudo permissions

Install
-------

TripleO CI Reproducer can be installed in your local environment or any remote
server. A typical setup includes local installations of Zuul, Nodepool and
Gerrit. Follow these 3 steps to install:

1. Install [package requirements](#requirements)

2. Clone this role `tripleo-ci-reproducer` to [`ANSIBLE_ROLES_PATH`](
   https://github.com/ansible/ansible/blob/devel/lib/ansible/config/base.yml#L1006),
   e.g. `~/.ansible/roles`, `/usr/share/ansible/roles` or `/etc/ansible/roles`:

   ```sh
   mkdir -p ~/.ansible/roles
   cd ~/.ansible/roles
   git clone https://github.com/rdo-infra/ansible-role-tripleo-ci-reproducer.git tripleo-ci-reproducer
   ```

2. [Configure a OpenStack project in `~/.config/openstack/clouds.yaml`](#openstack-project-configuration)
   if you use the OpenStack backend

3. Run [setup.yml](#setup-playbook) playbook to set up the OpenStack project used by the reproducer

   ```sh
   ansible-playbook -vv setup.yml -e "upstream_gerrit_user=<your_upstream_gerrit_user> rdo_gerrit_user=<your_rdo_gerrit_user>"
   ```

OpenStack Project Configuration
-------------------------------

Create a [`~/.config/openstack/clouds.yaml`](https://docs.openstack.org/python-openstackclient/latest/configuration/index.html)
if you want to run CI jobs on OpenStack compute instances:

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
  roles:
    - name: Set up reproducer
      role: tripleo-ci-reproducer
```

Role Variables
--------------

- `os_cloud_name` -- OpenStack cloud to use,
  as defined in [clouds.yaml](#openstack-project-configuration)
- `os_centos7_image` -- Image to use at centos-7 nodesets,
  default value is upstream-cloudinit-centos-7
- `os_centos8_image` -- Image to use at centos-8 nodesets,
  default value is upstream-cloudinit-centos-8
- `os_rhel8_image` -- Image to use at centos-8 nodesets,
  default value is upstream-cloudinit-rhel-8
- `os_centos9_image` -- Image to use at centos-9 nodesets,
  default value is upstream-cloudinit-centos-9
- `upstream_gerrit_user` -- User clone repos from review.opendev.org
- `rdo_gerrit_user` -- User clone repos from review.rdoproject.org,
  default value is `{{ ansible_user }}`
- `install_path` -- Path to install reproducer, after installation is
  possible to play with docker-compose commands for more advanced uses,
  defaults to `{{ ansible_user_dir }}/tripleo-ci-reproducer/`
- `state` -- Action to do `present` to start, `absent` to stop
- `tripleo_ci_gerrit_key` -- ssh key for the tripleo ci gerrit user if present
  it will be encrypted after zuul starts to be able to run the reproducer job
  `tripleo-ci-reproducer-fedora-28`
- `build_zuul` and `build_nodepool` -- Point to a zuul/nodepool version to use
  with `version` and `refspec` example:
  ```yaml
       build_zuul:
          version: FETCH_HEAD
          refspec: refs/changes/77/607077/1
       build_nodepool:
          version: HEAD
          refspec: refs/for/master
  ```
- `nodepool_provider` -- Type of nodepool provider to use,
  it has three possible values:
  + `openstack`: Use an OpenStack project
  + `host`: Use the host where docker-compose runs
  + `libvirt`: Start up a pair of libvirt domains at install and connects
    nodepool to it
- `teardown` -- Bootstraps VMs for libvirt provider from a scratch (default).
  No snapshots will be carried on (until combined with `restore_snapshot`)
- `create_snapshot` -- snapshots libvirt VMs before configuring it for Nodepool
- `restore_snapshot` -- restores libvirt VMs from a snapshot. Zuul will be
  reconfigured after that, and restored nodes will be added into Nodepool.
  If combined with `teardown`, restored nodes will re-run preparations playbook
- `zuul_job` -- zuul job to execute
- `zuul_job_retries` --  wait time for zuul job to start, default `20`
- `zuul_yaml` -- zuul config to run it overwrite `zuul_job`
- `depends_on` -- Gerrit reviews to test
- `user_pri_key` -- ssh private key to use for the user, default `id_rsa`
- `user_pub_key` -- ssh public key to use for the user, default `id_rsa.pub`
- `ssh_path` --  path where the ssh keys are present, default `~/.ssh`
- `launch_job_branch` -- branch to launch the job from, default `master`
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
  roles:
    - tripleo-ci-reproducer
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
  roles:
    - tripleo-ci-reproducer
```

Run standalone job over stable/rocky

```yaml
---
- name: Start reproducer
  hosts: virthost
  vars:
    zuul_job: tripleo-ci-centos-8-standalone
    launch_job_branch: stable/rocky
  roles:
    - tripleo-ci-reproducer
```

Testing trusted repository changes
----------------------------------

The current reproducer can help with testing changes in trusted Zuul repositories.

[Zuul repositories can be trusted and untrusted](https://zuul-ci.org/docs/zuul/user/config.html#security-contexts).
Patches that affect jobs with secrets submitted to trusted repositories can not
be tested prior to merge because of security context. This is when the reproducer
comes to rescue.

In the current reproducer code we install a custom Gerrit that contains two test
projects `test1` and `test2` and a config project `zuul-config`. The latter
is the trusted config repository for our setup. It includes some base jobs (not
inherited from upstream) and all TripleO CI related code copied from upstream.

In file `files/playbooks/add_rdo_config.yml` you will find files copied from the
[RDO config repo]() (https://github.com/rdo-infra/review.rdoproject.org-config)
to the local `zuul-config` repository. Secrets are stripped, because secrets from
different Zuul system cannot be used since they cannot be decrypted by a different
Zuul system. Eventually, all TripleO related code such as periodic jobs, playbooks,
roles etc. will be available in the `zuul-config` repository. These can be changed
and tested locally.

It is not possible to run jobs on patches for the config repository even if it is
local. But patches for `zuul-config` can be merged, which allows to run any job
in the `test1` repository which tests merged changes of `zuul-config`.

For example, the current workflow is recommended for testing `ovb-manage` role
in trusted repository of RDO:

First, [set up the reproducer as described in the install section](#install).
Verify that the OpenStack tenant is up at [`http://localhost:9000/t/tripleo-ci-reproducer/status`].

Now clone the `zuul-config` repository:

```sh
git clone http://localhost:8080/zuul-config
```

Go to the `zuul-config` directory and make all required changed to
`roles/ovb-manage/`. Commit and send for review using `admin` as Gerrit username:

```sh
git config --local gitreview.username "admin"
git commit -a -m "Change OVB manage role"
git review
```

Next, this patch has to be merged. Browse to Gerrit [`http://localhost:8080`]
and log in using the `admin` link on the page. View the change in Gerrit's
`My changes` page. Approve it by setting `+2` and `+Verified`. Once done,
click on button `Submit` and merge the change.

Alternatively, changes can be approved from the command line:

```sh
git push -f --set-upstream gerrit +HEAD:master
```

Update your local `zuul-config` to see that all changes have been merged:

```sh
cd zuul-config && git pull
```

If everything is OK, let's run a real OVB job. Clone `test1` project:

```sh
git clone http://localhost:8080/test1
```

Create a `zuul.yaml` file in the cloned repo:

```sh
cd test1 && touch zuul.yaml
```

Let's populate `zuul.yaml` file with necessary config to run an OVB job:

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

When using PSI/Upshift for running jobs, first create a
[`~/.config/openstack/clouds.yaml`](#openstack-project-configuration):

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
      mirror_fqdn: afs-mirror.sf.hosted.upshift.rdu2.redhat.com
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
```

Use any mirror which is available from PSI cloud, e.g. the local
`afs-mirror` or any rdo-cloud/vexxhost/upstream mirror.
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

Secrets are defined in `zuul.yaml` because they were removed from the `zuul-config`
repository in previous steps. Commit and push the changes as `admin`:

```sh
git config --local gitreview.username "admin"
git add *
gc -am "Run OVB change on this job"
git review
```

Check the Zuul tenant for running job in [`http://localhost:9000/t/tripleo-ci-reproducer/status`].
Open a console to see what is going on, `ssh` to a node, view logs of the
`zuul-executor` container, enable Zuul debugging etc. The currently running
OVB job uses code from the changed `ovb-manage` role.

If necessary, hold a nodepool node, for OVB it's `remove_ovb_after_job`
parameter in `zuul.yaml`.

```sh
docker-compose exec scheduler zuul autohold --tenant tripleo-ci-reproducer \
    --job tripleo-ci-centos-8-ovb-3ctlr_1comp-featureset001-test \
    --reason debug --project test1
```

License
-------

Apache

Author Information
------------------

Openstack Tripleo CI Team

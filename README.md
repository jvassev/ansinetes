# Introduction
Why is that every "Kubernetes getting started" guide takes tens of manuals steps? There has to be a simpler way.

Ansinetes (Ansible + Kubernetes) is a single command that lets you build multi-node high-availability clusters on CoreOS (on Vagrant or in your datacenter).
Ansinetes may not exhibit Ansible best practices but is a good starting point to (re)create non-trivial clusters with complex configuration easily. Also it maps every step to an easily hackable playbook for you to customize.

It has already taken some decisions for you:
* Uses CoreOS
* Uses the CoreOS distribution of Kubernetes in the form of [kubelet-wrapper](https://coreos.com/kubernetes/docs/latest/kubelet-wrapper.html)
* Uses flannel for the pod overlay network
* Configures TLS everywhere possible
* Ready to mount NFS and RBD volumes
* Runs the control plane in HA mode

# Prerequisites
* Linux or Mac
* Docker running locally (there will be volumes being host-mounted)
* Vagrant (only if you're going to use it)
* Some CoreOS'es idling around and you can ssh into them using a private key

# Install
```bash
curl -Ls -O https://raw.githubusercontent.com/jvassev/ansinetes/master/ansinetes
chmod +x ansinetes
```
You would probably put the script in ~/bin. Updating is just as easy `ansinetes -u`.

# Supported versions
* Kubernetes: 1.4.0 - 1.6.8 (you can control the k8s version deployed by editing the `k8s-config/vars.yaml` file)
* CoreOS: this depends on the kubernetes version (which determines the earliest Docker it supports)
* Docker (local): >= 1.10
* Helm >= 2.5

This script will pull an image from dockerhub with Ansible 2.x installed. On first run it will populate a local directory with playbooks and supporting resources.

# Booting a sensible Kubernetes cluster
A sensible cluster is defined by:
* HA control plane
* Secure component communication
* Only basic add-ons installed

## Enter the interactive Ansible environment
Pick a project name and run ansinetes. A directory named after the project will be created:

```bash
./ansinetes -p demo
 *** First run, copying default configuration
 *** Generating ssh key...
 *** Use this key for ssh:
ssh-rsa ... ansible-generated/initial
 *** Generating config.rb for Vagrant

[ansinetes@demo ~]$
```

You are dropped into a bash session (in a container) with ansible already installed and preconfigured. The project directory already contains some default configuration as well as the Ansible playbooks. The `-p` parameter expects a path to a folder and will create one if it doesn't exist.

## Start the Vagrant environment
In another shell navigate to demo/vagrant and start the VMs. Four VMs with 1GB of memory are started:
```bash
$ cd demo/vagrant
$ vagrant up
==> core-01: Importing base box 'coreos-beta'...
==> core-01: Matching MAC address for NAT networking...
==> core-01: Checking if box 'coreos-beta' is up to date.
...
```

## Prepare CoreOS for Ansible
CoreOS is usually configured using cloud-config but as a dev you are going to iterate faster if you stop/reconfigure/start your services, not the VMs. CoreOS needs to first be made [Ansible-compatible](https://galaxy.ansible.com/defunctzombie/coreos-bootstrap/). Luckily, this can be accomplished within Ansible itself.

```bash
[ansinetes@demo ~]$ ansible-playbook /etc/ansible/books/coreos-bootstrap.yaml

PLAY [coreos] ******************************************************************
...
```

## Create a CA
Certificates are created using [cfssl](https://github.com/cloudflare/cfssl). You can edit the demo/security/*.json files before creating the CA. The CA will not be auto-created to give you a chance to configure it. Defaults are pretty good though (at least for development). The json files are in the cfssl format. Finally, run the `kt-ca-init` command:

```bash
[ansinetes@demo ~]$ kt-ca-init
2016/09/02 20:49:24 [INFO] generating a new CA key and certificate from CSR
2016/09/02 20:49:24 [INFO] generate received request
2016/09/02 20:49:24 [INFO] received CSR
2016/09/02 20:49:24 [INFO] generating key: rsa-2048
2016/09/02 20:49:25 [INFO] encoded CSR
2016/09/02 20:49:25 [INFO] signed certificate with serial number 4640577027862920487
```

The ca.pem and ca-key.pem will be used for both etcd and Kubernetes later. The kt-* scripts are thin wrappers around cfssl and cfssljson. Server certificates are valid for all IP of a node (`ansible_all_ipv4_addresses`). For apiserver nodes the https certificate is also valid for the kubernets service IP (by default 10.254.0.1).

## Configure etcd
Etcd is essential both to Kubernetes and flannel. Ansinetes will deploy a 3-node cluster with the rest of the nodes working as proxies. This will enable every component to talk to localhost and target the etcd cluster. The cluster is bootstrapped using [static configuration](https://coreos.com/etcd/docs/latest/clustering.html#static).

```bash
[ansinetes@demo ~]$ ansible-playbook /etc/ansible/books/etcd-bootstrap.yaml
PLAY [Bootstrap etcd cluster] **************************************************
...
```

## Configure flannel
```bash
[ansinetes@demo ~]$ ansible-playbook /etc/ansible/books/flannel-bootstrap.yaml
PLAY [Configure and start flannel] *********************************************
...
```
The overlay network is 25.0.0.0/16 so it can easily be distinguished from other 10.*
networks lying around. That's fine unless you are going to communicate with the [British Ministry
of Defense](https://en.wikipedia.org/wiki/LogMeIn_Hamachi#Addressing). Flannel subnet can be configured.

## Configure Docker
Docker needs to be configured too, for example setting insecure registries. The `docker-bootstrap.yaml` book insertes a systemd drop-in file. You can add additional configs by editing `docker-config/20-registry.conf.j2` file.

```bash
[ansinetes@demo ~]$ ansible-playbook /etc/ansible/books/docker-bootstrap.yaml
PLAY [Configure Docker] ********************************************************
...
```

## Install Kubernetes
This step will install systemd units for every Kubernetes service on the nodes.

```bash
[ansinetes@demo ~]$ ansible-playbook /etc/ansible/books/kubernetes-bootstrap.yaml
PLAY [Install kubernetes on all nodes] *****************************************
...
```

## Create client configuration
To generate kubeconfigs and other client-side artifacts run clients.yaml:
```bash
[ansinetes@demo ~]$ ansible-playbook /etc/ansible/books/clients.yaml
...
```

To save some keystrokes you can accomplish all of the above steps using the `all.yaml` playbook:
```bash
[ansinetes@demo ~]$ ansible-playbook /etc/ansible/books/all.yaml
...
```

## Access your environment
Now that your cluser is running it's time to access it. In another shell
run `ansinetes -p demo -s` (-s for shell). It will start your $SHELL with a modified
environment, changed $PATH, changed $PS1 and `helm `, `kubectl` and `etcdctl` preconfigured. The changed prompt contains the project name and the current namespace:

```bash
$ ./ansinetes -p demo -s
Installing etcdctl locally...
######################################################################## 100.0%
Installing helm locally...
######################################################################## 100.0%
Installing kubectl locally...
######################################################################## 100.0%
Welcome to ansinetes virtual environment "demo"

# etctl is configured!
$ [demo:default] etcdctl member list
546c6cb8c021e3: name=a42bababcba440978f62d41d8b7e26b6 peerURLs=https://172.33.8.101:2380 clientURLs=https://172.33.8.101:2379 isLeader=false
6565485f164c9da3: name=5f6e37eb65d84199b5f3551959667537 peerURLs=https://172.33.8.102:2380 clientURLs=https://172.33.8.102:2379 isLeader=true
a0aca39404520794: name=adf5c02dd12a48419d681359438a2740 peerURLs=https://172.33.8.103:2380 clientURLs=https://172.33.8.103:2379 isLeader=false

# ... and so is kubectl :)
$ [demo:default] kubectl get no
NAME           STATUS    AGE
172.33.8.101   Ready     22m
172.33.8.102   Ready     22m
172.33.8.103   Ready     22m
172.33.8.104   Ready     22m

$ [demo:default] kubectl get pod --all-namespaces
NAMESPACE     NAME                                    READY     STATUS    RESTARTS   AGE
kube-system   kube-dns-v19-r2o5g                      3/3       Running   0          1m
kube-system   kubernetes-dashboard-2982215621-w1nu4   1/1       Running   0          1m
```

You can pass `-n NAMESPACE` and you will be dropped in the selected Kubernetes namespace, which will also be mirrored in your prompt.

Your old kubecfg will be left intact. In fact every time you enter a shell with `-s` the kubecfg will be enriched with configuration about the cluster and the full path to the project dir will be used as the context and cluster name.

While in a shell (`-s`) the `ssh` client is configured with a custom `ssh_config` file. This lets you ssh to your nodes referring to them by their Ansible inventory name or IP:

```bash
$ ./ansinetes -p demo -s -n web
Welcome to ansinetes virtual environment "demo"
$ [demo:web] ssh kbt-1
Container Linux by CoreOS stable (1409.7.0)
core@kbt-1 ~ $

```

Finally, for every ansinetes project/namespace a separate bash history is maintained. This is a great timesaver when you are dealing with long and complex `kubectl` invocations. Also it may prevent accidents as the history will contain entries valid only for the current project and/or namespace.

# Deployment description
There is no distinction between "master" nodes and kubelet nodes: you can assign nodes to any node and even can change your mind later. There can be multiple apiservers or schedulers, running on the same node or not. For example the default configuration is listed here:

```ini
[etcd-quorum-members]
kbt-1
kbt-2
kbt-3

[apiservers]
kbt-2
kbt-4

[schedulers]
kbt-1
kbt-3

[controller-managers]
kbt-4
kbt-3

[ingress-edges]
kbt-3

[kubelet]
kbt-1
kbt-2
kbt-3
kbt-4

[masters]
kbt-1
kbt-2
kbt-3
```

A kubelet/proxy runs everywhere while core services are carefully spread accross all 4 nodes. Schedulers and controllers run with `--leader-elect` option. The apiserver also runs in HA mode. On every node a ha-proxy is running that load balances between all the available apiservers. If an apiserver is down the health checks in the ha-proxy will detect it and will not forward requests to it. As a side effect, every node exposes the apiserver API on port 6443 and you can target an arbitrary node with `kubectl`.

All communucations between componentes is secured. There is no plain http communication. The services trust the certificate authority created by the `kt-init-ca` command.

The `masters` group in the inventory is only used when generating the client configuration. It is assumed that only a few nodes will be public even though all of them expose the same interface.

The `ingress-edges` dictates where to deploy the Nginx ingress controllers (using a node selector). You can put the IPs of the nodes in this groups behind a DNS and have a LoadBalancer-like exprience without a cloud provider.

Systemd units are installed uniformly everywhere but are enabled and started only on the designated nodes. If you change the service to node mapping you need to run `kubernetes-bootstrap.yaml` - this will only do the necessary changes and won't restart services needlessly.

Api-server is started with `--authorization-mode=ABAC`. Have a look at the `k8s-config/policy.jsonl` file for details.

Every component authenticates to the apiserver using a private key under a service account (mapping the CN to the username). The default service account for the kube-system namespace has all privileges.

Additionally an `admin` user is created and is used by `kubectl`. There is also username/password authentication configured for the admin user (for easy Dashboard access) with default password `pass123`. You can change it or add other users to the file `token.csv` during bootstrapping of the cluster.

Only four add-ons are deployed: Dashboard, DNS, Heapster and Registry. The add-ons yaml files may be touched a bit and made to work with ansible.

While not technically an add-on an OpenVPN [service](https://github.com/jvassev/openvpn-k8s) is also deployed by default. During development it is sometimes very useful to make your workstation part of the Kubernetes service network. When you run the playbook `clients.yaml` an openvpn client configuration is re-generated locally. You can then "join" the Kubernetes service and pod network using any openvpn client:
```bash
$ sudo openvpn --script-security 2 --config ovpn-client.conf
Sun Sep 18 22:40:05 2016 OpenVPN 2.3.7 x86_64-pc-linux-gnu [SSL (OpenSSL)] [LZO] [EPOLL] [PKCS11] [MH] [IPv6] built on Jul  8 2015
.....
Sun Sep 18 22:40:08 2016 /sbin/ip addr add dev tun0 local 10.241.0.6 peer 10.241.0.5
Sun Sep 18 22:40:08 2016 Initialization Sequence Completed
```

 Then, assuming you've established an OpenVPN connection successfully, you should be able to resolve the kube api-server:
```bash
$ nslookup kubernetes.default 10.254.0.2
Server:     10.254.0.2
Address:    10.254.0.2#53

Non-authoritative answer:
Name:   kubernetes.default.svc.cluster.local
Address: 10.254.0.1
```
While the OpenVPN bridge is opened you can target the pod themselves. This is not something you would do in production but is worth having around when troubleshooting.

OpenVPN client will also use the KubeDNS as your workstation DNS. You will be able to target any service by IP, any pod by it IP and also all services by their DNS name.


A docker registry is run in insecure mode. It is accessible at `registry.kube-system.svc:5000`: both from the kubelets and from the pod network. Once connected to the VPN you can push the registry if you add `--insecure-registry registry.kube-system.svc:5000` to you local docker config. This configuration is applied to all kubelet nodes so the same image name can be used in pod specs.

Ansinetes will also deploy DataDog and Sysdig daemonsets if enabled in the configuration. The yaml files are kept close the original versions, only the API key is set (and occasionally a bug fixed). If you wish to enable/disable these services run kubernetes-bootstrap.yaml again.

# Customizing the deployment
The easiest way to customize the deployment is to edit the `ansible/group_vars/all.yaml` file. You can control many options there. If you want to experiment with other Kubernetes config options you can edit the ansible/k8s-config/*.j2 templates. They are borrowed from the [init](https://github.com/Kubernetes/contrib/tree/master/init/systemd) contrib dir. If you find an option worthy of putting in a group var please contribute! The systemd unit files will hardly need to be touched though. The `hosts` can be changed to nodes.

The default `all.yaml` file looks like this
```yaml
flannel_config:
  Network: "25.0.0.0/16"
  Backend:
    Type: udp

kubernetes_cluster_ip_range: "10.254.0.0/16"

kubernetes_apiserver_ip: "10.254.0.1"

kubernetes_service_port_range: "30000-32767"

kubernetes_dns:
  ip: "10.254.0.2"
  domain: "cluster.local"

ovpn:
  replicas: 2
  network: "10.241.0.0"
  mask: "255.255.0.0"
  node_port: 30044

datadog:
  enabled: yes
  tags: "k1:v1,k2:v2"
  key: the_key

sysdig:
  enabled: no
  key: the_realkey

kubernetes_etcd_prefix: /registry

public_iface: ansible_eth1
```

# Starting over
If you are using this project maybe you like to experiment and break things. Run any of the *-bootstrap playbooks as often as you like. After boostraping you may need to run the *-up or *-down playbooks. Runbooks try to be idempotent and do as little work as possible.

## Regenerating the CA
Delete the security/ca.pem file, security/certs/* and run `kt-ca-init` again. The `etcd-bootstrap.yaml` and `Kubernetes-boostrap.yaml` need to be run again to distribute the new certificates and keys. By judiciously deleting *.pem file from the `cert` dir you can retrigger key re-generation and re-distribution.

## Purging cluster state
`etcd-purge.yaml` will purge etcd state. If you've messed up only Kubernetes, you can run only the `kubernetes-purge.yaml` playbook.

## Rotate SSH keys
Run the playbook `ssh-keys-rotate.yaml`. This will prevent ansible from talking to your vms unless you update the `vagrant/user-data` file with the security/new ansible-ssh-key.pub before the next reboot.

# Recommended workflow
The project directory fully captures the cluster config state including the Ansible scripts and Kubernetes customization. You can keep it under source control. You can later change the playbooks and/or the `hosts` file. The `ansinetes` script is guaranteed to work with somewhat modified project defaults.

I also prefer naming the ansible hosts in order not to deal with IPs. The kubelets assigns a label "ansible_hostname:{name}" to the nodes for usability. But really, every way is the right way as long as the hosts file contains the required groups.

# Why use ansinetes?
You would find ansinetes useful if you:
* want to test Kubernetes in an HA, multi-node deployment, a very specific version
* you are in a somewhat contrainted environment and want to make best use of a static pool of machines
* have some spare CoreOS VMs and want to quickly make a secure kube cluster with sensible config
* want to try the Kubernetes bleeding edge and can't wait for the packages to arrive for your distro
* want to painlessly try out obscure Kubernetes options
* want to the best debug experience in Kubernetes (private registry and full access to both the pod and the service networks)

# FAQ
* Why CoreOS? Because it nicely integrates docker with flannel. With a little extra work you could run ansinetes on every systemd-compatible distro.
* Do I have to use Vagrant? No, every CoreOS box that you can ssh into can be used. Beware though as it will wipe out your flannel/etcd configurations.
* Is federated Kubernetes supported? Not yet.

# Known issues
Addons may fail to install as download k8s on the nodes may take long time (it has to download about 250MB). The workaround is to `kubectl create -f` the yaml files.

# Resources
* [Kubernetes from scratch](http://Kubernetes.io/v1.0/docs/getting-started-guides/scratch.html)
* [Kubernetes the hard way](https://github.com/kelseyhightower/Kubernetes-the-hard-way)
* [Enabling HTTPS in an existing etcd cluster](https://coreos.com/etcd/docs/latest/etcd-live-http-to-https-migration.html)
* [Configuring flannel for container networking](https://coreos.com/flannel/docs/latest/flannel-config.html)
* [docker-Kubernetes-tls-guide](https://github.com/kelseyhightower/docker-Kubernetes-tls-guide)
* [OpenVPN for Kubernetes](https://github.com/offlinehacker/openvpn-k8s)

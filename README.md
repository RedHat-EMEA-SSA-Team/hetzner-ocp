# Set up OCP on libvirt on CentOS 7

## Installing server

When you get your server you get it without OS and it will be booted to rescue mode where you decide how it will be configured.

When you login to machine it will be running Debian based rescure system and welcome screen will be something like this

NOTE: If your system is not in rescue mode anymore, you can activate it from https://robot.your-server.de/server. Select your server and "Rescue" tab. From there select Linux, 64bit and public key if there is one.

![](images/set_to_rescue.png)

This will delete whatever you had on your system earlier and will bring the machine into it's rescue mode.
Please do not your new root password.

![](images/root_password.png)

After resetting your server, you are ready to connect to your system via ssh.

![](images/reset.png)

When you login to your server, the rescue system will display some hardware specifics for you:

```
-------------------------------------------------------------------

  Welcome to the Hetzner Rescue System.

  This Rescue System is based on Debian 8.0 (jessie) with a newer
  kernel. You can install software as in a normal system.

  To install a new operating system from one of our prebuilt
  images, run 'installimage' and follow the instructions.

  More information at http://wiki.hetzner.de

-------------------------------------------------------------------

Hardware data:

   CPU1: Intel(R) Core(TM) i7 CPU 950 @ 3.07GHz (Cores 8)
   Memory:  48300 MB
   Disk /dev/sda: 2000 GB (=> 1863 GiB)
   Disk /dev/sdb: 2000 GB (=> 1863 GiB)
   Total capacity 3726 GiB with 2 Disks

Network data:
   eth0  LINK: yes
         MAC:  6c:62:6d:d7:55:b9
         IP:   46.4.119.94
         IPv6: 2a01:4f8:141:2067::2/64
         RealTek RTL-8169 Gigabit Ethernet driver
```

From these information, the following ones are import to note:
* Number of disks (2 in this case)
* Memory
* Cores

`installimage` tool is used to install CentOS. It takes instructions from a text file.

Create new `config.txt` file
```
vi config.txt
```

Copy below content to that file as an template

```
DRIVE1 /dev/sda
DRIVE2 /dev/sdb
SWRAID 1
SWRAIDLEVEL 1
BOOTLOADER grub
HOSTNAME CentOS-73-64-minimal
PART /boot ext3     512M
PART lvm   vg0       all

LV vg0   root   /       ext4    1800G
LV vg0   swap   swap    swap       5G
LV vg0   tmp    /tmp    ext4      10G
LV vg0   home   /home   ext4      40G


IMAGE /root/.oldroot/nfs/install/../images/CentOS-73-64-minimal.tar.gz
```

There are some things that you will probably have to changes
* If you have a single disk remove line `DRIVE2` and lines `SWRAID*`
* If you have more than two disks add `DRIVE3`...
* If you dont need raid just change `SWRAID` to `0`
* Valid values for `SWRAIDLEVEL` are 0, 1 and 10. 1 means mirrored disks
* Configure LV sizes so that it matches your total disk size. In this example I have 2 x 2Tb disks RAID 1 so total diskspace available is 2Tb (1863 Gb)
* If you like you can add more volume groups and logical volumes.

When you are happy with file content, save and exit the editor via `:wq` and start instattion with following command

```
installimage -a -c config.txt
```

If there are error, you will be informed about then and you need to fix them.
At completion, the final output should be similar to

![](images/install_complete.png)

You are now ready to reboot your system into the newly installed OS.

```
reboot now
```

## Initialize tools

Install ansible and git

```
yum install -y ansible git
```

Create ssh key (no passphrase)

```
ssh-keygen
```

Clone configs and playbook. You need to add your ssh key to your Gitlab account.

```
git clone ssh://git@gitlab.consulting.redhat.com:2222/tigers/hetzner-ocp.git
```

## Install libvirt and setup environment

```
cd hetzner-ocp
ansible-playbook playbooks/setup.yml
export RHN_USERNAME=yourid@redhat.com
export RHN_PWD=yourpwd
```

## Provision guest

Check ```vars/guests.yml``` and modify it to correspond your environment. By default following VMs are installed:

* bastion
* master01
* infranode01
* node01

![](images/architecture.png)


Sample guest definition

```
    - name: bastion
      url: http://hetzner-static.s3-website-eu-west-1.amazonaws.com/rhel73/
      cpu: 1
      mem: 1024
      virt_type: kvm
      virt_hypervisor: hvm
      network: bridge=virbr0
      os:
          type: linux
          variant: rhel7.3
      disks:
          os:
            size: 12
            options: format=qcow2,cache=none,io=native
          data:
            size: 1
            options: format=qcow2,cache=none,io=native
      extra_args: ip=dhcp inst.ks=http://hetzner-static.s3-website-eu-west-1.amazonaws.com/ks/rhel-73-ocp.ks console=tty0 console=ttyS0,115200 quiet systemd.show_status=yes
```

Basically you need to change only num of VMs and/or cpu and mem values.

Provision VMs
```
ansible-playbook playbooks/provision.yml
```

Provisioning of the hosts take a while and they are in running state until installation is finnished. When guest list is empty, all guest are done and ready to be started.

```
virsh list
# installation still running
 Id    Name                           State
----------------------------------------------------
 34    bastion                        running
 35    master01                       running
 36    infranode01                    running
 37    node01                         running
 38    node02                         running
 39    node03                         running

```
When list of running guests is empty, all guests have been installed.

Start all VMs

```
ansible-playbook playbooks/startall.yml
```

Use below commands to copy SSH key to all VMs. Password for all hosts is p.

Before executing this playbook, clean all old ssl indentities from file /root/.ssh/known_hosts.

```
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i /root/inventory -k playbooks/prepare_ssl.yml
```

## Prepare bastion for OCP installation
You'll need your RHN username, password and subscription pool id (Employee SKU). You can get pool id from https://access.redhat.com/management/

When you have all mentioned above run.

```
ansible-playbook -i /root/inventory playbooks/prepare_guests.yml --extra-vars "rhn_username=$RHN_USERNAME rhn_password=$RHN_PWD"
```

## Install OCP

Installation of OCP is done on bastion host. So you need to ssh to bastion
```
ssh bastion
```

Installation is done with normal OCP installation playbooks. You can start installation with following command

```
ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml
```

When installation is done you can create new admin user and add hostpath persitent storage to registry with post install playbook.

Exit from bastion and execute following on hypervizor.

```
ansible-playbook -i /root/inventory hetzner-ocp/playbooks/post.yml
```

## Add persistent storage with hostpath
Note: For now this works only if you have single node :)
Check how much disk you have left `df -h`, if you have plenty then you can change pv disk size by modifying var named size in `playbooks/hostpath.yml`. You can also increase size of PVs by modifying array values...remembed to change both.

To start hostpath setup execute following on hypervizor
```
ansible-playbook -i /root/inventory playbooks/hostpath.yml
```


## Clean up everything
ansible-playbook playbooks/clean.yml
```

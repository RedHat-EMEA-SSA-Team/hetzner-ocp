# Set up OCP on libvirt on Fedora 25

## Insalling server

You need to install Fedora 25 to the server via VNC console from Heztner Robot UI.

You'll need VNC client to access VNC based installer, like [VNC Viewer](https://www.realvnc.com/en/download/viewer/) 

Activate VNC console, [screenshot](images/01_vnc_console.png)

Reboot server [screenshot](images/02_reboot.png)


Minimal install + basic tools is enough

I dont have good opinion about how to partiotion disks...In my tests I created a big root
````
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdb               8:16   0  1.8T  0 disk 
└─sdb1            8:17   0  1.8T  0 part 
  └─fedora-root 253:0    0  3.6T  0 lvm  /
sda               8:0    0  1.8T  0 disk 
├─sda2            8:2    0  1.8T  0 part 
│ ├─fedora-swap 253:1    0 23.7G  0 lvm  [SWAP]
│ └─fedora-root 253:0    0  3.6T  0 lvm  /
└─sda1            8:1    0    1G  0 part /boot
````

Remember to set some good root password during installation.

## Initialize tools

Install ansible

````
dnf install -y ansible
````

Create ssh key (no passphrase)

````
ssh-keygen
````

Clone configs and playbook

````
git clone https://gitlab.consulting.redhat.com:2222/tigers/hetzner-ocp.git
````

## Install libvirt

````
cd hetzner-ocp
ansible-playbook playbooks/virt.yml
````


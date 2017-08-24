# RHEL 7 OCP base kickstart file

install
text
zerombr
clearpart --all
bootloader --append="no_timer_check console=tty0 console=ttyS0,115200 ipv6.disable=0 selinux=1 quiet systemd.show_status=yes"
part /boot --size=512  --fstype=xfs
part pv.01 --size=1024 --grow --maxsize=10241
volgroup vg00 pv.01
logvol / --vgname=vg00 --size=10240 --fstype=xfs --name=lv_root
selinux --enforcing
auth --useshadow --passalgo=sha512
rootpw p
network --bootproto dhcp --onboot yes --hostname localhost
firewall --disabled
firstboot --disabled
lang en_US.UTF-8
timezone --utc America/New_York
keyboard fi
services --enabled tuned
poweroff

%addon com_redhat_kdump --enable --reserve-mb=auto
%end

%packages --instLangs=en_US
@Core
NetworkManager
#NetworkManager-config-routing-rules
#NetworkManager-dispatcher-routing-rules
bash-completion
bind-utils
bzip2
chrony
deltarpm
#docker
#container-selinux
git
iotop
kexec-tools
libselinux-python
man-pages
mlocate
nano
net-tools
nfs-utils
openssh-clients
psmisc
qemu-guest-agent
screen
sos
strace
tcpdump
telnet
tuned
unzip
wget
yum-utils

-biosdevname
-btrfs-progs
-dracut-config-rescue
-firewalld
-*firmware*
#+linux-firmware
-iprutils
-kernel-tools
-microcode_ctl
-ntp
-ntpdate
-plymouth
-rdma
-Red_Hat_Enterprise_Linux-Release_Notes-7-en-US
-redhat-support-tool
-*rhn*
%end

%post
# GRUB / console
sed -i -e 's,GRUB_TIMEOUT=.,GRUB_TIMEOUT=1,' /etc/default/grub
sed -i -e 's,GRUB_TERMINAL.*,GRUB_TERMINAL="serial console",' /etc/default/grub
sed -i -e '/GRUB_SERIAL_COMMAND/d' -e '$ i GRUB_SERIAL_COMMAND="serial --speed=115200"' /etc/default/grub
#sed -i -e 's/ console=tty0//' -e 's/ console=ttyS0,115200//' /etc/default/grub
sed -i -e 's, rhgb,,g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
systemctl enable serial-getty@ttyS0.service
#systemctl enable serial-getty@ttyS1.service
#echo ttyS1 >> /etc/securetty

# Guest Agent / Performance
mkdir -p /etc/qemu-ga /etc/tuned
echo '[general]' > /etc/qemu-ga/qemu-ga.conf
echo 'verbose=1' >> /etc/qemu-ga/qemu-ga.conf
echo virtual-guest > /etc/tuned/active_profile

# ssh/d
sed -i -e 's,^#UseDNS.*,UseDNS no,' /etc/ssh/sshd_config
sed -i -e 's,^GSSAPIAuthentication yes,GSSAPIAuthentication no,' /etc/ssh/sshd_config
# https://lists.centos.org/pipermail/centos-devel/2016-July/014981.html
echo "OPTIONS=-u0" >> /etc/sysconfig/sshd

# Packages - keys
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release > /dev/null 2>&1

# Packages - trimming
echo "%_install_langs en_US" > /etc/rpm/macros.image-language-conf
#echo "%_excludedocs 1" > /etc/rpm/macros.excludedocs-conf
echo "override_install_langs=en_US" >> /etc/yum.conf
#echo "tsflags=nodocs" >> /etc/yum.conf

# Packages - update
yum -y update
if [ $(rpm -q kernel | wc -l) -gt 1 ]; then
  rpm -e $(rpm -q --last kernel | awk 'FNR>1{print $1}')
fi

# Services
systemctl disable systemd-readahead-collect.service systemd-readahead-drop.service systemd-readahead-replay.service

# Make sure rescue image is not built without a configuration change
echo dracut_rescue_image=no > /etc/dracut.conf.d/no-rescue.conf

# Cosmetics (get rid of some harmless syslog messages)
/bin/rm -f /usr/lib/systemd/system/dbus-org.freedesktop.network1.service

# Finalize
truncate -s 0 /etc/resolv.conf
rm -f /var/lib/systemd/random-seed
restorecon -R /etc > /dev/null 2>&1 || :

# Clean
yum -C clean all
/bin/rm -rf /etc/*- /etc/*.bak /root/* /tmp/* /tmp/.pki /var/tmp/*
/bin/rm -rf /var/cache/yum/* /var/lib/yum/history/* /var/lib/yum/repos/*
/bin/rm -rf /var/lib/yum/yumdb/* /var/log/yum.log
/bin/rm -rf /var/log/dracut.log /var/log/anaconda*
%end

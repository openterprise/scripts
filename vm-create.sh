#!/bin/bash

#requirements
#- cloud image qcow2
#- virt-install installed

#folders
KVM_VM_FOLDER="/home/pawel/KVM_VMs"
ISO_FOLDER="/home/pawel/ISO"

#VM parameters
VM_DISK_SIZE="128G"
VM_RAM="2048"
VM_VCPUS="2"
VM_BRIDGE="virbr1"


#display script usage
if [ $# != 3 ]
then
	echo "Usage: $0 OSFAMILY VMNAME IPADDR"
	exit
fi


#getting variables from CLI parameters
OSFAMILY=$1
VMNAME=$2
IPADDR=$3


#list at:
#osinfo-query os
#
#CentOS7 - working fine
#OpenSUSE - IP is set, password changed, need to perform "zypper updage" before first reboot (without update there is kernel panic after reboot)
#Ubuntu - IP not set, using DHCP
#Debian8.6.1 - password not changed, no SSH access, no static IP, cloud-init not starting
#after VM creation boot from live DVD in rescue mode, then user passwd utility, then regenerate RSA and DSA keys for sshd
#

#choosing image files for OS Family
case "$OSFAMILY" in
"centos")  echo "OS: CentOS"
	VM_OS_VARIANT="centOS7.0"
	CLOUD_IMAGE_FOLDER="$ISO_FOLDER/CentOS"
	CLOUD_IMAGE_FILE="CentOS-7-x86_64-GenericCloud-1701.qcow2"
	IFNAME="eth0"
	;;
"fedora")  echo "OS: Fedora"
	VM_OS_VARIANT="fedora23"
	CLOUD_IMAGE_FOLDER="$ISO_FOLDER/Fedora"
	CLOUD_IMAGE_FILE="Fedora-Cloud-Base-25-20161121.0.x86_64.qcow2"
	IFNAME="eth0"
	;;
"opensuse")  echo "OS: OpenSUSE"
	VM_OS_VARIANT="openSUSE13.2"
	CLOUD_IMAGE_FOLDER="$ISO_FOLDER/OpenSUSE"
	CLOUD_IMAGE_FILE="openSUSE-Leap-42.1-OpenStack.x86_64-0.0.4-Build2.88.qcow2"
	IFNAME="eth0"
	;;
"ubuntu") echo "OS: Ubuntu"
	VM_OS_VARIANT="ubuntu14.04"
	CLOUD_IMAGE_FOLDER="$ISO_FOLDER/Ubuntu"
	CLOUD_IMAGE_FILE="xenial-server-cloudimg-amd64-disk1.img"
	IFNAME="ens3"
	;;
"debian") echo  "OS: Debian"
	VM_OS_VARIANT="debian8"
	CLOUD_IMAGE_FOLDER="$ISO_FOLDER/Debian"
	CLOUD_IMAGE_FILE="debian-8.7.1-20170215-openstack-amd64.qcow2"
	IFNAME="eth0"
	;;
*) echo "OS: Unknown"
	exit
	;;
esac


#checking for duplicated VM name
if [ -e "$KVM_VM_FOLDER/$VMNAME.qcow2" ]
then
	echo "$KVM_VM_FOLDER/$VMNAME.qcow2 file already exist"
	exit
fi

#create NEW big qcow2
echo 'Creating new qcow2 image...'
qemu-img create -f qcow2 $KVM_VM_FOLDER/$VMNAME.qcow2 $VM_DISK_SIZE

#copy data to new qcow image
printf "\nCopying data to new qcow image...\n"
virt-resize --expand /dev/sda1 $CLOUD_IMAGE_FOLDER/$CLOUD_IMAGE_FILE $KVM_VM_FOLDER/$VMNAME.qcow2

#creating user-data for cloud-init
cat > $KVM_VM_FOLDER/tmp/user-data <<EOL
#cloud-config
password: password
chpasswd:
  list: |
    root:password
  expire: False
ssh_pwauth: True
disable_root: false

#below workaround for Ubuntu (setting SSHD: PermitRootLogin yes)
runcmd:
- sed -i'.orig' -e's/prohibit-password/yes/' /etc/ssh/sshd_config
- service sshd restart
EOL

#creating meta-data for cloud-init
cat > $KVM_VM_FOLDER/tmp/meta-data <<EOL
instance-id: $VMNAME;
local-hostname: $VMNAME
hostname: $VMNAME

network-interfaces: |
  #below sets "ONBOOT=yes
  auto $IFNAME
  iface $IFNAME inet static
  address $IPADDR
  network 10.10.10.0
  netmask 255.255.255.0
  broadcast 10.10.10.255
  gateway 10.10.10.1
  dns-nameservers 10.10.10.1

#below workaround for previous bug in cloud-init
bootcmd:
- ifdown $IFNAME
- ifup $IFNAME
EOL

#creating ISO file with config files for cloud-init
genisoimage -output $KVM_VM_FOLDER/tmp/$VMNAME-cidata.iso -volid cidata -joliet -rock $KVM_VM_FOLDER/tmp/user-data $KVM_VM_FOLDER/tmp/meta-data

#installing and running new VM in KVM
virt-install --noautoconsole --ram $VM_RAM --vcpus $VM_VCPUS --accelerate -n $VMNAME --disk $KVM_VM_FOLDER/$VMNAME.qcow2 --bridge $VM_BRIDGE --import --os-variant $VM_OS_VARIANT --disk $KVM_VM_FOLDER/tmp/$VMNAME-cidata.iso,device=cdrom

#install ok?
if [[ $? != 0 ]];
then 
	exit; 
fi

#getting VM MAC
data=`virsh dumpxml $VMNAME | grep 'mac address'`

#parsing XML for MAC ADDRESS
MACADDR=$(sed -n -e "s/.*<mac address='\(.*\)'\/>.*/\1/p" <<< $data)

printf "VM MAC: $MACADDR\n\n"

printf "Booting VM...\n\n"; 

echo 'Staring arp-scan...'

while :
do
	#arp-scan for particular MAC
	data=`arp-scan -I $VM_BRIDGE --local | grep $MACADDR`

	#when MAC is found process returns 0, when MAC is NOT found process returns 1
	if [[ $? == 0 ]]; then break; fi

	#progress indicator...	
	printf '.'
done

#arp-scan results
printf "\nFound:\n"
echo $data


#getting IP ADDRESS
IPADDR=`echo $data | awk '{print $1}'`

printf "\nTrying to ping VM...\n"

ping -c 3 $IPADDR

printf "\nSSH connect command:\n"

printf "ssh root@$IPADDR\n\n"



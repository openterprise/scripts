#!/bin/bash

#requirements
#- cloud image qcow2
#- virt-install installed

#folders
KVM_VM_FOLDER="/home/pawel/KVM_VMs"
ISO_FOLDER="/home/pawel/ISO"
SSH_KEY_FILE="/home/pawel/.ssh/id_rsa.pub"

#auth
PASSWORD="password"
SSH_KEY=`cat $SSH_KEY_FILE`

#VM parameters
VM_DISK_SIZE="128G"
VM_RAM="2048"
VM_VCPUS="2"
VM_BRIDGE="virbr1"


#display script usage
if [ $# != 3 ]
then
	echo "Usage: $0 OSFAMILY IPADDR VMNAME"
	exit
fi


#getting variables from CLI parameters
OSFAMILY=$1
VMNAME=$3
IPADDR=$2


#list at: osinfo-query os
#CentOS7/8 - working fine
#Fedora32 - working fine
#OpenSUSE15.2 - working fine, DNS is not set
#Ubuntu20.04 - unable to boot (grub rescue)
#Debian10 - unable to boot (grub rescue)

#choosing image files for OS Family
case "$OSFAMILY" in
"centos")  echo "OS: CentOS"
	VM_OS_VARIANT="centos8"
	CLOUD_IMAGE_FOLDER="$ISO_FOLDER/CentOS"
	CLOUD_IMAGE_FILE="CentOS-8-GenericCloud-8.2.2004-20200611.2.x86_64.qcow2"
	IFNAME="eth0"
	;;
"fedora")  echo "OS: Fedora"
	VM_OS_VARIANT="fedora32"
	CLOUD_IMAGE_FOLDER="$ISO_FOLDER/Fedora"
	CLOUD_IMAGE_FILE="Fedora-Cloud-Base-32-1.6.x86_64.qcow2"
	IFNAME="eth0"
	;;
"opensuse")  echo "OS: OpenSUSE"
	VM_OS_VARIANT="opensuse15.1"
	CLOUD_IMAGE_FOLDER="$ISO_FOLDER/OpenSUSE"
	CLOUD_IMAGE_FILE="openSUSE-Leap-15.2-OpenStack.x86_64.qcow2"
	IFNAME="eth0"
	;;
"ubuntu") echo "OS: Ubuntu"
	VM_OS_VARIANT="ubuntu20.04"
	CLOUD_IMAGE_FOLDER="$ISO_FOLDER/Ubuntu"
	CLOUD_IMAGE_FILE="focal-server-cloudimg-amd64.img"
	IFNAME="ens3"
	;;
"debian") echo  "OS: Debian"
	VM_OS_VARIANT="debian10"
	CLOUD_IMAGE_FOLDER="$ISO_FOLDER/Debian"
	CLOUD_IMAGE_FILE="debian-10-genericcloud-amd64-20200610-293.qcow2"
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

timezone: "Europe/Warsaw"

users:
  - name: visit
    groups: wheel
    ssh-authorized-keys:
      - $SSH_KEY

  - name: root
    ssh-authorized-keys:
      - $SSH_KEY

password: $PASSWORD
chpasswd:
  list: |
    visit:$PASSWORD
    root:$PASSWORD
  expire: False
ssh_pwauth: True
disable_root: false

runcmd:
- sudo touch /etc/cloud/cloud-init.disabled
#below workaround for Ubuntu (setting SSHD: PermitRootLogin yes)
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

#remove config files after ISO creation
rm $KVM_VM_FOLDER/tmp/user-data
rm $KVM_VM_FOLDER/tmp/meta-data

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
	data=`arp-scan -I $VM_BRIDGE --local -B 10M -t 250 | grep $MACADDR`

	#when MAC is found process returns 0, when MAC is NOT found process returns 1
	if [[ $? == 0 ]]; then break; fi

	#progress indicator...	
	printf '.'
done

#arp-scan results
printf "\nFound:\n"
echo $data


#unmount ISO
printf "\nUnmounting temp ISO image: $VMNAME-cidata.iso\n"

# get name of target path
targetDrive=$(virsh domblklist $VMNAME | grep $VMNAME-cidata.iso | awk {' print $1 '})

# force ejection of CD
virsh change-media $VMNAME --path $targetDrive --eject --force --config

#remove temp ISO
rm $KVM_VM_FOLDER/tmp/$VMNAME-cidata.iso

#getting IP ADDRESS
IPADDR=`echo $data | awk '{print $1}'`

printf "\nTrying to ping VM...\n"

ping -i 0.2 -c 5 $IPADDR

printf "\nSSH connect command:\n"

printf "ssh root@$IPADDR\n\n"



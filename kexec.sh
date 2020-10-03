#!/bin/bash
latestkernel=`ls -t /boot/vmlinuz-* | sed "s/\/boot\/vmlinuz-//g" | head -n1`
echo "kernel current: $(uname -r)"
echo "kernel target:  ${latestkernel}"
echo ""
echo "Arming kexec..."
#kexec -l /boot/vmlinuz-${latestkernel} --initrd=/boot/initramfs-${latestkernel}.img --append="`cat /proc/cmdline`"
kexec -l /boot/vmlinuz-${latestkernel} --initrd=/boot/initramfs-${latestkernel}.img --reuse-cmdline
echo ""
read -p "Press [Enter] key to start new kernel..."
#systemctl start kexec.target
kexec -e

#!/bin/bash

echo ssh-rsa RSA-KEY RSA-KEY-NAME >> /home/centos/.ssh/authorized_keys

yum update -y
yum install bash-completion bind-utils mc vim wireshark httpd -y
systemctl enable httpd
systemctl start httpd

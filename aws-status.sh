#!/bin/bash

echo "VMs running:"
#list all instances states
aws ec2 describe-instances --filters Name=instance-state-name,Values=running | jq .Reservations[].Instances[].InstanceId

echo "VMs stopped:"
#list all instances states
aws ec2 describe-instances --filters Name=instance-state-name,Values=stopped | jq .Reservations[].Instances[].InstanceId

echo "Public IPs:"
aws ec2 describe-instances | jq .Reservations[].Instances[].PublicIpAddress | grep -v null | sed 's/\"//g'

echo "Private IPs:"
aws ec2 describe-instances | jq .Reservations[].Instances[].PrivateIpAddress | grep -v null | sed 's/\"//g'

echo "Volumes in-use:"
#list all volumes
aws ec2 describe-volumes --filters Name=status,Values=in-use | jq .Volumes[].VolumeId

echo "Volumes available (not attached):"
#list all volumes
aws ec2 describe-volumes --filters Name=status,Values=available | jq .Volumes[].VolumeId


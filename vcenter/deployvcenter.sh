#!/bin/bash
# set the variables
echo Provide your Datastore name, e.g. datastore1
read DATASTORE

echo Provide the password for your ESXi server - if your password contains an ! be sure to proceed the ! with a \\
read PASS

echo Provide the password for vCenter - if your password contains an ! be sure to proceed the ! with a \\
read GOVCPASS

echo Provide the full path to the vCenter ISO file, e.g. /home/gkeadmin/VMware-VCSA-all-6.7.0-10244745.iso 
read VCPATH

# prepare the installer template
cp vcenterinstall.json.template vcenterinstall.json
sed -i -e "s/DATASTORE/$DATASTORE/g" vcenterinstall.json
sed -i -e "s/GOVCPASS/$GOVCPASS/g" vcenterinstall.json
sed -i -e "s/PASS/$PASS/g" vcenterinstall.json

# mount the iso
mkdir /mnt/iso
mount -o loop $VCPATH /mnt/iso

# run the installer
/mnt/iso/vcsa-cli-installer/lin64/vcsa-deploy install --no-esx-ssl-verify --accept-eula vcenterinstall.json

# give vcenter some time to boot
sleep 180

#set govc enviromentals
export GOVC_URL=https://172.16.10.2/sdk
export GOVC_USERNAME=administrator@gkeonprem.local
export GOVC_PASSWORD=$GOVCPASS
export GOVC_INSECURE=true

#configure vcenter
govc datacenter.create 'GKE On-Prem'
govc cluster.create 'GKE On-Prem' 
govc cluster.change -drs-enabled=true -drs-mode=manual 'GKE On-Prem'
govc pool.create '*/GKE On-Prem'
govc cluster.add -cluster 'GKE On-Prem' -hostname 172.16.10.3 -username gkeadmin -password $PASS -noverify 

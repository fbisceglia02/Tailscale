#!/bin/bash
# Generare una public key per ogni vm

resourceGroup='rg-ts-demo'
username='azureuser'

vmList=$(az vm list -g $resourceGroup | jq -r '.[].name')

for vm in $vmList; do
    echo "the vm is $vm"
    cd output
    vm=$(echo "$vm" | sed 's/[^A-Za-z0-9._-]/_/g')
    mkdir $vm
    ssh-keygen -t rsa -b 2048 -f "./$vm/key" -N ""
    az vm user update --resource-group $resourceGroup --name $vm --username $username --ssh-key-value "./$vm/key.pub"
    mv $vm "output/$vm"
done


sleep 100
exit 0

ssh-keygen -t rsa -b 2048 -f "./output/$vm-key" -N ""




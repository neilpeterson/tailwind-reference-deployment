#!/bin/bash
set -e

# Credentials
azureClientID=$CLIENT_ID
azureClientSecret=$SECRET
adminUser=twtadmin
adminPassword=Password2020

# Azure and VM configurations
azureResourceGroup=$RESOURCE_GROUP_NAME
locaton=$LOCATION
randomName=$RANDOM

# Print out tail command
printf "\n*** To tail logs, run this command... ***\n"
echo "*************** Container logs ***************"
echo "az container logs --name bootstrap-container --resource-group $azureResourceGroup --follow"
echo "*************** Connection Information ***************"

# Create Azure Cosmos DB
az cosmosdb create --name $randomName --resource-group $azureResourceGroup --kind MongoDB

# Create Azure SQL Insance
az sql server create --location $locaton --resource-group $azureResourceGroup --name $randomName --admin-user $adminUser --admin-password $adminPassword

# Create Azure VM
az vm create --name $randomName --resource-group $azureResourceGroup --image Win2019Datacenter --admin-username $adminUser --admin-password $adminPassword
az vm open-port --port 80 --resource-group $azureResourceGroup --name $randomName

sleep 20m

az vm extension set --name CustomScriptExtension --publisher Microsoft.Compute --version 1.9 --vm-name $randomName --resource-group $azureResourceGroup \
  --settings '{"fileUris":["https://raw.githubusercontent.com/neilpeterson/tailwind-reference-deployment/standalone/deployment-artifacts-standalone-azure/config-windows.ps1"],"commandToExecute":"powershell.exe -ExecutionPolicy Unrestricted -file config-windows.ps1"}'

# Notes
echo "*************** Connection Information ***************"
echo "The Tailwind Traders Website can be accessed at:"
echo "http://$INGRESS"
echo ""
echo "Run the following to connect to the AKS cluster:"
echo "az aks get-credentials --name $AKS_CLUSTER --resource-group $azureResourceGroup --admin"
echo "******************************************************"
#!/bin/bash
set -e

# Credentials
azureClientID=$CLIENT_ID
azureClientSecret=$SECRET
adminUser=twtadmin
adminPassword=Password2020!

# Azure and VM configurations
azureResourceGroup=$RESOURCE_GROUP_NAME
locaton=$LOCATION
randomName=twtapp3

# Print out tail command
printf "\n*** To tail logs, run this command... ***\n"
echo "*************** Container logs ***************"
echo "az container logs --name bootstrap-container --resource-group $azureResourceGroup --follow"
echo $randomName
echo "*************** Connection Information ***************"

# Create Azure Cosmos DB
az cosmosdb create --name $randomName --resource-group $azureResourceGroup --kind MongoDB
cosmosConnectionString=$(az cosmosdb list-connection-strings --name $randomName --resource-group $azureResourceGroup --query connectionStrings[0].connectionString -o tsv)

# Create Azure SQL Insance
az sql server create --location $locaton --resource-group $azureResourceGroup --name $randomName --admin-user $adminUser --admin-password $adminPassword
az sql db create --resource-group twt-001 --server twtapp2 --name tailwind
sqlConnectionString=$(az sql db show-connection-string --server twtapp2 --name tailwind -c ado.net)

# Create Azure VM
az vm create --name $randomName --resource-group $azureResourceGroup --image UbuntuLTS --admin-username $adminUser --admin-password $adminPassword
az vm open-port --port 80 --resource-group $azureResourceGroup --name $randomName
az vm extension set --name customScript --publisher Microsoft.Azure.Extensions --vm-name $randomName --resource-group $azureResourceGroup \
  --settings '{"fileUris":["https://raw.githubusercontent.com/neilpeterson/tailwind-reference-deployment/master/deployment-artifacts-standalone-azure-linux-vm/config-linux.sh"],"commandToExecute": "bash ./config-linux.sh $sqlConnectionString $cosmosConnectionString"}'
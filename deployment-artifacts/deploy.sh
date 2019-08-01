#!/bin/bash
set -e

# Tailwind repositories
BACKEND=https://github.com/microsoft/TailwindTraders-Backend.git

# Values from Bootstrap Template
AKS_TEMPLATE=TailwindTraders-Backend/Deploy/deployment.json
CHARTS=TailwindTraders-Backend/Deploy/helm
CLIENT_ID=$CLIENT_ID
HELM_SCRIPT=TailwindTraders-Backend/Deploy/Generate-Config.ps1
IMAGES=TailwindTraders-Backend/Deploy/tt-images
REGISTRY=neilpeterson
RESOURCE_GROUP_NAME=$RESOURCE_GROUP_NAME
SECRET=$SECRET
SECRETS_SCRIPT=TailwindTraders-Backend/Deploy/Create-Secret.ps1
SERVICE_ACCOUNT=TailwindTraders-Backend/Deploy/helm/ttsa.yaml
SERVICE_PATH=TailwindTraders-Backend/Source/Services
VALUES=../../../test123.yaml

# SQL Server Credentials
SQL_ADMIN=sqladmin
SQL_PASSWORD=Password12

# Get backend code
printf "\n*** Clone Tailwind Backend Repository... ***\n"
git clone $BACKEND

# Deploy backend infrastructure (ACR, Storage Account, AKS, website, PostgreSQL, SQL Server, Cosmos, MongoDB )
printf "\n*** Deploying resources: this will take a few minutes... ***\n"

az group deployment create -g $RESOURCE_GROUP_NAME --template-file $AKS_TEMPLATE \
  --parameters servicePrincipalId=$CLIENT_ID servicePrincipalSecret=$SECRET $sqladmin=$SQL_ADMIN \
  sqlServerAdministratorLoginPassword=$SQL_PASSWORD aksVersion=1.13.5 pgversion=10

# Install Helm on Kubernetes cluster
printf "\n*** Installing Tiller on Kubernets cluster... ***\n"

AKS_CLUSTER=$(az aks list --resource-group $RESOURCE_GROUP_NAME --query [0].name -o tsv)
az aks get-credentials --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP_NAME --admin
kubectl apply -f https://raw.githubusercontent.com/Azure/helm-charts/master/docs/prerequisities/helm-rbac-config.yaml
helm init --service-account tiller

# Create postgres DB, Disable SSL, and set Firewall
printf "\n*** Create stockdb Postgres database... ***\n"
POSTGRES=$(az postgres server list --resource-group $RESOURCE_GROUP_NAME --query [0].name -o tsv)
az postgres db create -g $RESOURCE_GROUP_NAME -s $POSTGRES -n stockdb
az postgres server update --resource-group $RESOURCE_GROUP_NAME --name $POSTGRES --ssl-enforcement Disabled
az postgres server firewall-rule create --resource-group $RESOURCE_GROUP_NAME \
  --server-name $POSTGRES --name AllowAllAzureIps --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Create Helm values file
printf "\n*** Create Helm values file... ***\n"
pwsh $HELM_SCRIPT -resourceGroup $RESOURCE_GROUP_NAME -sqlPwd Password12 -outputFile test123.yaml

# Create Kubernetes / ACR secrets
# printf "\n*** Create ACR secrets in Kubernetes... ***\n"

# ACR=$(az acr list -g $RESOURCE_GROUP_NAME --query [0].name -o tsv)
# pwsh $SECRETS_SCRIPT -resourceGroup $RESOURCE_GROUP_NAME -acrName $ACR

# Create Kubernetes Service Account
printf "\n*** Create Helm service account in Kubernetes... ***\n"
kubectl apply -f $SERVICE_ACCOUNT

# Deploy application to Kubernetes
printf "\n***Deplpying applications to Kubernetes.***\n"

INGRESS=$(az aks show -n $AKS_CLUSTER -g $RESOURCE_GROUP_NAME --query addonProfiles.httpApplicationRouting.config.HTTPApplicationRoutingZoneName -o tsv)

helm install --name my-tt-product -f $VALUES --set az.productvisitsurl=http://your-product-visits-af-here --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/product.api --set image.tag=latest $CHARTS/products-api
helm install --name my-tt-coupon -f $VALUES --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/coupon.api --set image.tag=latest $CHARTS/coupons-api
helm install --name my-tt-profile -f $VALUES --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/profile.api --set image.tag=latest $CHARTS/profiles-api
helm install --name my-tt-popular-product -f $VALUES --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/popular-product.api --set image.tag=latest --set initImage.repository=$REGISTRY/popular-product-seed.api --set initImage.tag=latest $CHARTS/popular-products-api
helm install --name my-tt-stock -f $VALUES --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/stock.api --set image.tag=latest $CHARTS/stock-api
helm install --name my-tt-image-classifier -f $VALUES --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/image-classifier.api --set image.tag=latest $CHARTS/image-classifier-api
helm install --name my-tt-cart -f $VALUES --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/cart.api --set image.tag=latest $CHARTS/cart-api
helm install --name my-tt-login -f $VALUES --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/login.api --set image.tag=latest $CHARTS/login-api
helm install --name my-tt-mobilebff -f $VALUES --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/mobileapigw --set image.tag=latest $CHARTS/mobilebff
helm install --name my-tt-webbff -f $VALUES --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/webapigw --set image.tag=latest $CHARTS/webbff

# Deploy website Images
printf "\n***Copying application images (graphics) to Azure storage.***\n"

STORAGE=$(az storage account list -g $RESOURCE_GROUP_NAME -o table --query  [].name -o tsv)
BLOB_ENDPOINT=$(az storage account list -g $RESOURCE_GROUP_NAME --query [].primaryEndpoints.blob -o tsv)
CONNECTION_STRING=$(az storage account show-connection-string -n $STORAGE -g $RESOURCE_GROUP_NAME -o tsv)
az storage container create --name "coupon-list" --public-access blob --connection-string $CONNECTION_STRING
az storage container create --name "product-detail" --public-access blob --connection-string $CONNECTION_STRING
az storage container create --name "product-list" --public-access blob --connection-string $CONNECTION_STRING
az storage container create --name "profiles-list" --public-access blob --connection-string $CONNECTION_STRING
az storage blob upload-batch --destination $BLOB_ENDPOINT --destination coupon-list  --source $IMAGES/coupon-list --account-name $STORAGE
az storage blob upload-batch --destination $BLOB_ENDPOINT --destination product-detail --source $IMAGES/product-detail --account-name $STORAGE
az storage blob upload-batch --destination $BLOB_ENDPOINT --destination product-list --source $IMAGES/product-list --account-name $STORAGE
az storage blob upload-batch --destination $BLOB_ENDPOINT --destination profiles-list --source $IMAGES/profiles-list --account-name $STORAGE

# Deploy Website
git clone https://github.com/neilpeterson/TailwindTraders-Website.git

# Build and push web
cd TailwindTraders-Website/Source/Tailwind.Traders.Web
az acr build -r $ACR -t web .
cd ../../../

# Create web Helm release
helm install --name web -f TailwindTraders-Website/Deploy/helm/gvalues.yaml --set ingress.protocol=http --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/web --set image.tag=latest  TailwindTraders-Website/Deploy/helm/web/

# Notes
echo "*************** Connection Information ***************"
echo "******************************************************"
echo "The Tailwind Traders Website can be accessed at:"
echo "http://$INGRESS"
echo ""
echo "Run the following to connect to the AKS cluster:"
echo "az aks get-credentials --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP_NAME --admin"
echo "******************************************************"
echo "******************************************************"
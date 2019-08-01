#!/bin/bash
set -e

# Values from Bootstrap Template
AKS_TEMPALTE=TailwindTraders-Backend/Deploy/deployment.json
CHARTS=TailwindTraders-Backend/Deploy/helm
CLIENT_ID=$CLIENT_ID
HELM_SCRIPT=TailwindTraders-Backend/Deploy/Generate-Config.ps1
IMAGES=TailwindTraders-Backend/Deploy/tt-images
REGISTRY=neilpeterson
RESOURCE_GROUP_NAME=$RESOURCE_GROUP_NAME
SECRET=$SECRET
SERVICE_ACCOUNT=TailwindTraders-Backend/Deploy/helm/ttsa.yaml
SERVICE_PATH=TailwindTraders-Backend/Source/Services
VALUES=../../../values.yaml

# Get backend code
printf "\n*** Cloning Tailwind code repository... ***\n"

# Issue to fix with upstream: https://github.com/microsoft/TailwindTraders-Backend/blob/master/Deploy/Generate-Config.ps1#L92
git clone https://github.com/neilpeterson/TailwindTraders-Backend.git

# # Deploy backend infrastructure
# printf "\n*** Deploying resources: this will take a few minutes... ***\n"

# az group deployment create -g $RESOURCE_GROUP_NAME --template-file $AKS_TEMPALTE \
#   --parameters servicePrincipalId=$CLIENT_ID servicePrincipalSecret=$SECRET \
#   sqlServerAdministratorLogin=sqladmin sqlServerAdministratorLoginPassword=Password12 \
#   aksVersion=1.13.5 pgversion=10

# Install AKS
az ake create --name test123 --resourceGroup $RESOURCE_GROUP_NAME

# Install Helm on Kubernetes cluster
printf "\n*** Installing Tiller on Kubernets cluster... ***\n"

AKS_CLUSTER=$(az aks list --resource-group $RESOURCE_GROUP_NAME --query [0].name -o tsv)
az aks get-credentials --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP_NAME --admin
kubectl apply -f https://raw.githubusercontent.com/Azure/helm-charts/master/docs/prerequisities/helm-rbac-config.yaml
helm init --wait --service-account tiller

# Create postgres DB, Disable SSL, and set Firewall
printf "\n*** Create stockdb Postgres database... ***\n"

POSTGRES=$(az postgres server list --resource-group $RESOURCE_GROUP_NAME --query [0].name -o tsv)
az postgres db create -g $RESOURCE_GROUP_NAME -s $POSTGRES -n stockdb
az postgres server update --resource-group $RESOURCE_GROUP_NAME --name $POSTGRES --ssl-enforcement Disabled
az postgres server firewall-rule create --resource-group $RESOURCE_GROUP_NAME --server-name $POSTGRES --name AllowAllAzureIps --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Create Helm values file
printf "\n*** Create Helm values file... ***\n"

pwsh $HELM_SCRIPT -resourceGroup $RESOURCE_GROUP_NAME -sqlPwd Password12 -outputFile values.yaml

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

# Issue to fix with upstream: https://github.com/microsoft/TailwindTraders-Website/commit/0ab7e92f437c45fd6ac5c7c489e88977fd1f6ebc
git clone https://github.com/neilpeterson/TailwindTraders-Website.git
helm install --name web -f TailwindTraders-Website/Deploy/helm/gvalues.yaml --set ingress.protocol=http --set ingress.hosts={$INGRESS} --set image.repository=$REGISTRY/web --set image.tag=latest TailwindTraders-Website/Deploy/helm/web/

# Copy website images to storage
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

# Notes
echo "*************** Connection Information ***************"
echo "The Tailwind Traders Website can be accessed at:"
echo "http://$INGRESS"
echo ""
echo "Run the following to connect to the AKS cluster:"
echo "az aks get-credentials --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP_NAME --admin"
echo "******************************************************"
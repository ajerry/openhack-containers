aksname="Openhack2021"

resourcegroup="teamResources"
location="australiaeast"

# Create the Azure AD application
serverApplicationId=$(az ad app create \
    --display-name "${aksname}Server" \
    --identifier-uris "https://${aksname}Server" \
    --query appId -o tsv)

# Update the application group memebership claims
az ad app update --id $serverApplicationId --set groupMembershipClaims=All

# Create a service principal for the Azure AD application
az ad sp create --id $serverApplicationId


# Get the service principal secret
serverApplicationSecret=$(az ad sp credential reset \
    --name $serverApplicationId \
    --credential-description "AKSPassword" \
    --query password -o tsv)

# Add permissions for the Azure AD app to read directory data, sign in and read
# user profile, and read directory data
az ad app permission add \
    --id $serverApplicationId \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope 06da0dbc-49e2-44d2-8312-53f166ab848a=Scope 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role

# Grant permissions for the permissions assigned in the previous step
# You must be the Azure AD tenant admin for these steps to successfully complete
az ad app permission grant --id $serverApplicationId --api 00000003-0000-0000-c000-000000000000
az ad app permission admin-consent --id  $serverApplicationId

# Create the Azure AD client application
clientApplicationId=$(az ad app create --display-name "${aksname}Client" --native-app --reply-urls "https://${aksname}Client" --query appId -o tsv)

# Create a service principal for the client application
az ad sp create --id $clientApplicationId

# Get the oAuth2 ID for the server app to allow authentication flow
oAuthPermissionId=$(az ad app show --id $serverApplicationId --query "oauth2Permissions[0].id" -o tsv)

# Assign permissions for the client and server applications to communicate with each other
az ad app permission add --id $clientApplicationId --api $serverApplicationId --api-permissions $oAuthPermissionId=Scope
az ad app permission grant --id $clientApplicationId --api $serverApplicationId

# Create a resource group the AKS cluster
#az group create --name $resourcegroup --location $location

# Get the Azure AD tenant ID to integrate with the AKS cluster
tenantId=$(az account show --query tenantId -o tsv)

#grant Service Principle to the AKS subnets
az role assignment create --assignee $serverApplicationId --role "Network Contributor" 

# Create the AKS cluster and provide all the Azure AD integration parameters
az aks create \
  --resource-group $resourcegroup \
  --name $aksname \
  --node-count 1 \
  --network-plugin azure \
   --vnet-subnet-id /subscriptions/0f06b719-cd36-45e8-823a-5cc0b8c684dd/resourceGroups/teamResources/providers/Microsoft.Network/virtualNetworks/vnet/subnets/aks-subnet \
    --docker-bridge-address 172.17.0.1/16 \
    --dns-service-ip 10.2.2.10 \
    --service-cidr 10.2.2.0/24 \
    --generate-ssh-keys \
    --attach-acr registrylzn7863 \
  --aad-server-app-id $serverApplicationId \
  --aad-server-app-secret $serverApplicationSecret \
  --aad-client-app-id $clientApplicationId \
  --aad-tenant-id $tenantId

# Get the admin credentials for the kubeconfig context
az aks get-credentials --resource-group $resourcegroup --name $aksname --admin

#RBAC bind
az aks get-credentials --resource-group teamResources --name $aksname --admin

kubectl config view

az ad user show --upn-or-object-id hacker30ca@OTAPRD1492ops.onmicrosoft.com --query objectId -o tsv

az ad group show --group aks-cluster-admin --query objectId -o tsv
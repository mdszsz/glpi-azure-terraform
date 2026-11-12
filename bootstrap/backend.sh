#!/usr/bin/env bash
set -euo pipefail
LOCATION=eastus
RG=rg-tfstate-eus-001
SA=sttfstateglpi$RANDOM   # anote o nome gerado

az group create -n $RG -l $LOCATION
az storage account create -n $SA -g $RG -l $LOCATION \
  --sku Standard_LRS --min-tls-version TLS1_2 \
  --allow-blob-public-access false --allow-shared-key-access false
az storage account blob-service-properties update \
  -n $SA -g $RG --enable-versioning true --enable-delete-retention true --delete-retention-days 14

ME=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee $ME \
  --role "Storage Blob Data Contributor" \
  --scope $(az storage account show -n $SA -g $RG --query id -o tsv)

sleep 30   # tempo para a permissão propagar
az storage container create --name tfstate --account-name $SA --auth-mode login
echo "Storage Account: $SA"
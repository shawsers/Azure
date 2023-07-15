#!/bin/bash
#START
#Created by Jason Shaw - jason.shaw@ibm.com
#Date: July 15, 2023

#TO DO
## 1. Prompt for Operator and Turbo version and update in yamls
## 2. Prompt for Azure creds and update in the tfvars file
## 3. Add option to save Azure creds (using local EXPORT COMMAND) for future re-use or one time use only
## 4. Programatically pull down all files from GitHub to make this fully automated end to end

#Log start date and time
SDATE=$(date)
DS=$(date -u +"%H%M%S")

#Screen output colours
RED=`tput setaf 1`
WHITE=`tput setaf 7`
GREEN=`tput setaf 2`
BLUE=`tput setaf 4`
YELLOW=`tput setaf 3`
NC=`tput sgr0` # No Color

cd /Users/jasonshaw/Documents/terraform/learn-terraform-provision-aks-cluster
echo "${GREEN}**SCRIPT STARTING**"
echo " "
echo "TURBONOMIC OPERATOR VERSION TO BE INSTALLED IS:${WHITE}"
mv operator.yaml operator.yaml.$DS
curl -O https://raw.githubusercontent.com/turbonomic/t8c-install/master/operator/deploy/operator.yaml
cat operator.yaml | grep "image:" | awk {'print $2'}
echo " "
#Add prompt for operator version change
echo "${BLUE}Press any key to continue or wait 5 seconds..."
read -s -n 1 -t 5
echo " "

echo "${GREEN}TURBONOMIC XL VERSION TO BE INSTALLED IS:${WHITE}"
mv turbo_cr.yaml turbo_cr.yaml.$DS
curl -O https://raw.githubusercontent.com/shawsers/random/main/turbo_cr.yaml
cat turbo_cr.yaml | grep "tag:"
echo " "
#Add prompt for turbo version change
echo "${BLUE}Press any key to continue or wait 5 seconds..."
read -s -n 1 -t 5
echo " "

echo "${GREEN}TERRAFORM IS GOING TO CREATE THE AKS CLUSTER NOW..."
echo "${BLUE}LAST CHANCE TO CANCEL...continuing in 5 seconds..."
read -s -n 1 -t 5
echo " "

echo "${GREEN}APPLYING TERRAFORM - THIS STEP WILL TAKE A FEW MINS${WHITE}"
terraform apply -auto-approve
echo " "

echo "${GREEN}TERRAFORM DONE - GETTING OUTPUT${WHITE}"
terraform output kube_config > kubeconfig.yaml
echo "Done"
echo " "

echo "${GREEN}UPDATING KUBECONFG FILE FOR USE${WHITE}"
sed '1d' kubeconfig.yaml > kubeconfig1.yaml
sed '$d' kubeconfig1.yaml > kubeconfignew.yaml
export KUBECONFIG=$(pwd)/kubeconfignew.yaml
echo "Done"
echo " "

echo "${GREEN}**OUTPUT 4 x NODES - CONFIRMS CONNECTION TO AKS CLUATER**${WHITE}"
kubectl get nodes
echo " "

echo "${GREEN}CREATING TURBONOMIC NAMESPACE${WHITE}"
kubectl create namespace turbonomic
echo " "

echo "${GREEN}SETTING CONTEXT TO TURBONOMIC NAMESPACE${WHITE}"
kubectl config set-context --current --namespace=turbonomic
echo " "

echo "${GREEN}DEPLOYING CRD...${WHITE}"
kubectl create -f https://raw.githubusercontent.com/turbonomic/t8c-install/master/operator/config/crd/bases/charts.helm.k8s.io_xls.yaml
echo " "

echo "${GREEN}CREATE SERVICE ACCOUNT...${WHITE}"
kubectl create -f https://raw.githubusercontent.com/turbonomic/t8c-install/master/operator/deploy/service_account.yaml -n turbonomic
echo " "

echo "${GREEN}CREATE CLUSTER ROLE...${WHITE}"
kubectl create -f https://raw.githubusercontent.com/turbonomic/t8c-install/master/operator/deploy/cluster_role.yaml -n turbonomic
echo " "

echo "${GREEN}CREATE CLUSTER ROLE BINDING...${WHITE}"
kubectl create -f https://raw.githubusercontent.com/turbonomic/t8c-install/master/operator/deploy/cluster_role_binding.yaml -n turbonomic
echo " "

echo "${GREEN}CREATE AND LAUNCH THE OPERATOR...${WHITE}"
#Turbo version is hard coded in this local file, need to update it manually after deployment
kubectl create -f operator.yaml -n turbonomic
echo " "

echo "${GREEN}WAITING FOR 30 SECONDS TO LET THE OPERATOR START UP...${WHITE}"
sleep 30
kubectl get pods -n turbonomic | grep t8c
echo " "

echo "${GREEN}CREATE AND LAUNCH TURBONOMIC XL...${WHITE}"
#Turbo version is hard coded in this local file, need to update it manually after deployment
kubectl apply -f turbo_cr.yaml -n turbonomic
echo " "

echo "${GREEN}WAITING FOR 2 MINUTES TO LET THE TURBONOMIC PODS START UP...${WHITE}"
sleep 120
echo " "

echo "${GREEN}HERE ARE THE PVC's CREATED...${WHITE}"
kubectl get pvc -n turbonomic
echo " "

echo "${GREEN}HERE ARE ALL OF THE PODS...${WHITE}"
kubectl get pods -n turbonomic
echo " "

echo "${GREEN}CHECKING STATUS OF TURBONOMIC PODS...${WHITE}"
for i in $(kubectl get deployments -n turbonomic --no-headers | awk {'print $1'})
    do 
        NR=$(kubectl get deployment $i -n turbonomic --no-headers | awk {'print $4'})
        if [[ ${NR} = 0 ]]; then
            echo "${RED}Turbonomic pod $i is not ready yet"
        fi
    done
echo " "

echo "${GREEN}IP ADDRESS TO CONNECT TO TURBONOMIC WEB UI${WHITE}"
turbo=$(kubectl get services -n turbonomic | grep nginx | awk {'print $4'})
echo "https://$turbo"
echo " "

echo "${GREEN}OPENING WEB BROWSER TO TURBONOMIC WEB UI${WHITE}"
open https://$turbo
echo " "

echo "${GREEN}**SCRIPT IS COMPLETE NOW**${WHITE}"
echo "Script Start Time: ${SDATE}"
EDATE=$(date)
echo "Script End Time: ${EDATE}"
echo "${BLUE}NOTE: If you want to destroy the AKS Cluster run: terraform destroy -auto-approve${NC}"
#END

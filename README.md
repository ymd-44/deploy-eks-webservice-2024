# deploy-eks-webservice-2024 : Procédure d'installation
## Prérequis
- Compte AWS de créé
- Utilisateur IAM : https://docs.aws.amazon.com/IAM/latest/UserGuide/iam-config.html#create-an-admin
- Installation de "kubectl": https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
- Installation de la commande "eksctl": https://eksctl.io/installation/
- Installation de Helm pour la gestion des packages Kubernetes: https://helm.sh/docs/intro/install/

## Création d’un cluster EKS
eksctl create cluster \
--name eks-devops24 \
--region us-east-1 \
--zones us-east-1a,us-east-1b \
--managed 

## Vérification des informations sur notre cluster
kubectl cluster-info

## Vérification de la création des ressources
kubectl get all

## Vérification des informations détaillées sur les pods et noeuds
kubectl get pods -o wide -A

## Création d'un fournisseur IAM OIDC pour le cluster EKS
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html

## Création d’un fournisseur OIDC IAM
oidc_id=$(aws eks describe-cluster --name eks-devops24 --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4
eksctl utils associate-iam-oidc-provider --cluster eks-devops24 --approve

## Création d'un compte IAM avec les politiques nécessaires
- https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html

## Création de role IAM 
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user.html

## Permissions attachés au role 
- AmazonEC2ContainerRegistryReadOnly
- AmazonEKSWorkerNodePolicy
- AmazonEKS_CNI_Policy

## Définition des permissions EBS CSI au rôle crée (gestion des volumes EBS)
eksctl create iamserviceaccount \
--name ebs-csi-controller-sa \
--namespace kube-system \
--cluster eks-devops24 \
--attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
--approve \
--role-name AmazonEC2forEKSdevops

## Recupération de l'ARN de notre rôle IAM
role_arn=$(aws iam list-roles --query "Roles[?RoleName=='AmazonEC2forEKSdevops'].Arn" --output text)

## Installation du pilote EBS CSI
eksctl create addon --name aws-ebs-csi-driver --cluster eks-devops24 --service-account-role-arn $role_arn --force

## Cas d'erreur lors de l'installation 
Ajout du plugin EBS CSI au rôle : https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html

## Déploiement du pilote EBS CSI en utilisant Helm
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
helm upgrade --install aws-ebs-csi-driver \
    --namespace kube-system \
    aws-ebs-csi-driver/aws-ebs-csi-driver

## Vérification des pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

kubectl get all -n kube-system

## Déploiemnt de l'infrastructure dans le Cloud AWS
- Execution du fichier ".ghithub\worklows\github-actions-ci.yaml"
- Checks du pipeline dans le repo : https://github.com/ymd-44/deploy-eks-webservice-2024/actions

## Vérification de la création des objets
## Pods: 
kubectl get pods
## Secrets: 
kubectl get secrets
## PVC : 
kubectl get pvc
## Services: 
kubectl get svc
## Suppression du cluster 
eksctl delete cluster eks-devops24

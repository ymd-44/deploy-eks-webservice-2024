terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.33.0"
    }
    #Installation de "kubectl"
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.26.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      component    = "terraform"
      creator      = "walid yahia-mohamed"
      environment  = "serviceweb wordpress"
      product      = "cloudwatch dashboard"
      purpose      = "infrastructure"
      usage        = "automation"
    }
  }
}

# Création d’un cluster EKS
resource "aws_eks_cluster" "eks-devops24" {
 name = "eks-devops24-cluster"
 role_arn = aws_iam_role.eks-iam-role.arn
 version  = "1.30"

 access_config {
    authentication_mode = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

 vpc_config {
  endpoint_private_access = false
  endpoint_public_access  = true
  subnet_ids = [var.subnet_id_1, var.subnet_id_2]
 }

 depends_on = [
  aws_iam_role.eks-iam-role,
 ]
}

#Access entires AWS/k8s
resource "aws_eks_access_entry" "user-iam" {
  cluster_name      = aws_eks_cluster.eks-devops24.name
  principal_arn     = "arn:aws:iam::793599617947:user/user-iam"
  kubernetes_groups = ["group-1", "group-2"]
  type              = "STANDARD"
}

#Utilisateur IAM : Configurez la première ressource pour le rôle IAM.
resource "aws_iam_role" "eks-iam-role" {
    name = "eks-devops24-iam-role"

 path = "/"

 assume_role_policy = <<EOF
{
 "Version" : "2012-10-17",
 "Statement" : [
  {
   "Effect" : "Allow",
   "Principal" : {
    "Service" : "eks.amazonaws.com"
   },
   "Action": "sts:AssumeRole"
  }
 ]
}
EOF

}


# Permissions attachés au role 
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
 policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
 role    = aws_iam_role.eks-iam-role.name
}


# Permissions attachés au nœud de travail EKS.
resource "aws_iam_role" "workernodes" {
  name = "eks-node-group-devops24"
 
  assume_role_policy = jsonencode({
   Statement = [{
    Action = "sts:AssumeRole"
    Effect = "Allow"
    Principal = {
     Service = "ec2.amazonaws.com"
    }
   }]
   Version = "2012-10-17"
  })
 }
 

 resource "aws_iam_role_policy_attachment" "nodes-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role    = aws_iam_role.workernodes.name
 }
 
 resource "aws_iam_role_policy_attachment" "nodes-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role    = aws_iam_role.workernodes.name
 }
 
 resource "aws_iam_role_policy_attachment" "nodes-EC2InstanceProfileForImageBuilderECRContainerBuilds" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  role    = aws_iam_role.workernodes.name
 }
 
 resource "aws_iam_role_policy_attachment" "nodes-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role    = aws_iam_role.workernodes.name
 }


#New : Création des nœuds de travail pour le cluster
resource "aws_eks_node_group" "worker-node-group" {
  cluster_name  = aws_eks_cluster.eks-devops24.name
  node_group_name = "eks-devops24-workernodes"
  node_role_arn  = aws_iam_role.workernodes.arn
  subnet_ids   = [var.subnet_id_1, var.subnet_id_2]
  instance_types = ["m5.large"]
 
  scaling_config {
   desired_size = 1
   max_size   = 2
   min_size   = 1
  }

  update_config {
    max_unavailable = 1
  }
 
  depends_on = [
   aws_iam_role_policy_attachment.nodes-AmazonEKSWorkerNodePolicy,
   aws_iam_role_policy_attachment.nodes-AmazonEKS_CNI_Policy,
   aws_iam_role_policy_attachment.nodes-AmazonEC2ContainerRegistryReadOnly,
  ]
  
  # Optional: Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
 }

#CloudWatch : monitoring aws
resource "aws_cloudwatch_dashboard" "demo-dashboard" {
  dashboard_name = "demo-dashboard-EKS"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId",
              "eks"
            ]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "EKS - CPU Utilization"
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 7
        width  = 3
        height = 3

        properties = {
          markdown = "Dashboard EKS Datascientest"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            [
              "AWS/EC2",
              "NetworkIn",
              "InstanceId",
              "eks"
            ]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "EKS - NetworkIn"
        }
      }
    ]
  })
}


# Cloud Watch alarm : CPU utilization

resource "aws_cloudwatch_metric_alarm" "eks-cpu-alarm" {
  alarm_name                = "terraform-eks-cpu-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 120
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "This metric monitors ec2 cpu utilization reaches 80%"
  insufficient_data_actions = []
}
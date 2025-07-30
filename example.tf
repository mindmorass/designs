provider "aws" {
  region = "us-east-1"
}

locals {
  cluster_name = "demo-eks"
  domain_name  = "example.com" # Update this to your Route53 domain
}

# =====================
# VPC (for EKS)
# =====================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

# =====================
# EKS Cluster
# =====================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Fargate profile
  fargate_profiles = {
    default = {
      selectors = [
        {
          namespace = "default"
        }
      ]
    }
  }
}

# =====================
# Sample Application (Fargate)
# =====================
resource "kubernetes_namespace" "demo" {
  metadata {
    name = "demo"
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deployment"
    namespace = kubernetes_namespace.demo.metadata[0].name
    labels = {
      app = "nginx"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx_service" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.demo.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" : "alb"
    }
  }
  spec {
    selector = {
      app = "nginx"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}

# =====================
# Route53 record for ALB
# =====================
data "aws_route53_zone" "selected" {
  name         = local.domain_name
  private_zone = false
}

resource "aws_route53_record" "alb_dns" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "eks.${local.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [kubernetes_service.nginx_service.status[0].load_balancer[0].ingress[0].hostname]
}


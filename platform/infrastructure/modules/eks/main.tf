module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # Networking
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Cluster access
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = var.api_access_cidrs

  # Encryption for secrets
  cluster_encryption_config = [{
    provider_key_arn = var.kms_key_arn
    resources        = ["secrets"]
  }]

  # Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Node groups for different cell types
  eks_managed_node_groups = {
    # External and Channel cells (public subnet access)
    public_cells = {
      name           = "public-cells"
      instance_types = ["m6g.xlarge"] # Graviton processors for cost efficiency
      ami_type       = "AL2023_ARM_64" # Amazon Linux 2023 ARM

      subnet_ids     = var.public_subnet_ids
      min_size       = 2
      max_size       = 6
      desired_size   = 2

      labels = {
        role = "public"
        cells = "external,channel"
      }

      taints = []
    }

    # Core infrastructure cells (private access)
    core_cells = {
      name           = "core-cells"
      instance_types = ["m6g.2xlarge"]
      ami_type       = "AL2023_ARM_64"

      subnet_ids     = var.private_subnet_ids
      min_size       = 3
      max_size       = 10
      desired_size   = 3

      labels = {
        role = "core"
        cells = "logic,security,integration"
      }

      taints = []
    }

    # Data cells with high storage needs
    data_cells = {
      name           = "data-cells"
      instance_types = ["r6g.2xlarge"] # Memory optimized
      ami_type       = "AL2023_ARM_64"

      subnet_ids     = var.database_subnet_ids
      min_size       = 2
      max_size       = 8
      desired_size   = 2

      labels = {
        role = "data"
        cells = "data"
      }

      taints = [{
        key    = "cell"
        value  = "data"
        effect = "NoSchedule"
      }]
    }

    # ML and recommendation cells with compute needs
    ml_cells = {
      name           = "ml-cells"
      instance_types = ["c6g.4xlarge"] # Compute optimized
      ami_type       = "AL2023_ARM_64"

      subnet_ids     = var.private_subnet_ids
      min_size       = 1
      max_size       = 6
      desired_size   = 2

      labels = {
        role = "ml"
        cells = "recommendation,simulation"
      }

      taints = [{
        key    = "cell"
        value  = "ml"
        effect = "NoSchedule"
      }]
    }

    # Observability cells
    observability_cells = {
      name           = "observability-cells"
      instance_types = ["m6g.2xlarge"]
      ami_type       = "AL2023_ARM_64"

      subnet_ids     = var.private_subnet_ids
      min_size       = 2
      max_size       = 4
      desired_size   = 2

      labels = {
        role = "observability"
        cells = "observability"
      }

      taints = [{
        key    = "cell"
        value  = "observability"
        effect = "NoSchedule"
      }]
    }
  }

  # Tags
  tags = merge(
    var.tags,
    {
      "Environment" = var.environment
      "ManagedBy" = "Terraform"
    }
  )
}

# EKS Module for Kubernetes Clusters

# EKS Cluster
resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.api_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  tags = merge(
    {
      Name = var.cluster_name
    },
    var.tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]
}

# EKS Cluster Security Group
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for the EKS cluster control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-cluster-sg"
    },
    var.tags
  )
}

# EKS Cluster IAM Role
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.cluster_name}-cluster-role"
    },
    var.tags
  )
}

# EKS Cluster IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# Managed Node Group (On-Demand Instances)
resource "aws_eks_node_group" "ondemand" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "${var.cluster_name}-ondemand-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.ondemand_node_desired_size
    max_size     = var.ondemand_node_max_size
    min_size     = var.ondemand_node_min_size
  }

  instance_types = var.ondemand_instance_types
  capacity_type  = "ON_DEMAND"
  disk_size      = var.node_disk_size

  tags = merge(
    {
      Name = "${var.cluster_name}-ondemand-nodes"
    },
    var.tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# Managed Node Group (Spot Instances)
resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "${var.cluster_name}-spot-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.spot_node_desired_size
    max_size     = var.spot_node_max_size
    min_size     = var.spot_node_min_size
  }

  instance_types = var.spot_instance_types
  capacity_type  = "SPOT"
  disk_size      = var.node_disk_size

  tags = merge(
    {
      Name = "${var.cluster_name}-spot-nodes"
    },
    var.tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# EKS Node IAM Role
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.cluster_name}-node-role"
    },
    var.tags
  )
}

# EKS Node IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# EKS Node Security Group
resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for the EKS worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name                                        = "${var.cluster_name}-node-sg"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    },
    var.tags
  )
}

# Allow inbound traffic between nodes
resource "aws_security_group_rule" "node_self" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 65535
  type                     = "ingress"
}

# Allow inbound traffic from cluster to nodes
resource "aws_security_group_rule" "node_cluster_inbound" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  to_port                  = 65535
  type                     = "ingress"
}

# Allow outbound traffic from cluster to nodes
resource "aws_security_group_rule" "cluster_node_outbound" {
  description              = "Allow the cluster control plane to communicate with worker nodes"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 65535
  type                     = "egress"
}

# Allow inbound traffic from nodes to cluster
resource "aws_security_group_rule" "cluster_node_inbound" {
  description              = "Allow nodes to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 443
  type                     = "ingress"
}

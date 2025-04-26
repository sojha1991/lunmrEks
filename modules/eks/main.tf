resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

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
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids = var.private_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

resource "aws_iam_role" "eks_node_group" {
  name = "${var.project_name}-eks-node-group-role"

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
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_launch_template" "eks_worker" {
  name_prefix   = "${var.project_name}-eks-worker-"
  image_id      = data.aws_ami.eks_worker.id
  instance_type = var.node_instance_types[0]
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups            = [aws_security_group.eks_worker.id]
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    cluster_name = aws_eks_cluster.main.name
    cluster_endpoint = aws_eks_cluster.main.endpoint
    cluster_certificate = aws_eks_cluster.main.certificate_authority[0].data
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-eks-worker"
    }
  }
}

resource "aws_autoscaling_group" "eks_worker" {
  name                = "${var.project_name}-eks-worker-asg"
  vpc_zone_identifier = var.private_subnet_ids
  desired_capacity    = 1
  max_size           = 2
  min_size           = 1

  launch_template {
    id      = aws_launch_template.eks_worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value              = "${var.project_name}-eks-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${aws_eks_cluster.main.name}"
    value              = "owned"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "eks_worker" {
  name_prefix = "${var.project_name}-eks-worker-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-worker-sg"
  }
}

data "aws_ami" "eks_worker" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.eks_version}-*"]
  }
} 
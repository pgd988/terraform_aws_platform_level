data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# --- GitLab ---
resource "aws_iam_role" "gitlab" {
  name               = "gitlab-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "gitlab" {
  name = "gitlab-ec2-profile"
  role = aws_iam_role.gitlab.name
}

resource "aws_iam_role_policy_attachment" "gitlab_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.gitlab.name
}

# --- RabbitMQ ---
resource "aws_iam_role" "rabbitmq" {
  name               = "rabbitmq-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "rabbitmq" {
  name = "rabbitmq-ec2-profile"
  role = aws_iam_role.rabbitmq.name
}

resource "aws_iam_role_policy_attachment" "rabbitmq_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.rabbitmq.name
}

# --- MongoDB ---
resource "aws_iam_role" "mongodb" {
  name               = "mongodb-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "mongodb" {
  name = "mongodb-ec2-profile"
  role = aws_iam_role.mongodb.name
}

resource "aws_iam_role_policy_attachment" "mongodb_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.mongodb.name
}

# --- Monitoring ---
resource "aws_iam_role" "monitoring" {
  name               = "monitoring-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "monitoring" {
  name = "monitoring-ec2-profile"
  role = aws_iam_role.monitoring.name
}

resource "aws_iam_role_policy_attachment" "monitoring_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.monitoring.name
}

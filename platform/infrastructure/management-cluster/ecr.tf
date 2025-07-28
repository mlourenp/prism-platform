# ECR Repositories for Prism Platform
# These repositories will be the source of truth for your container images
resource "aws_ecr_repository" "this" {
  count = var.create_ecr_repository ? length(var.ecr_repository_names) : 0

  name                 = var.ecr_repository_names[count.index]
  image_tag_mutability = var.ecr_image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.ecr_image_scanning_configuration.scan_on_push
  }

  tags = var.tags
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "this" {
  count = var.create_ecr_repository && var.ecr_lifecycle_policy ? length(var.ecr_repository_names) : 0

  repository = aws_ecr_repository.this[count.index].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.ecr_max_image_count} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.ecr_max_image_count
      }
      action = {
        type = "expire"
      }
    }]
  })
}

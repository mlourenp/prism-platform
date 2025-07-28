# Multi-region deployment module for Prism Platform

# Route53 Global DNS Zone
resource "aws_route53_zone" "prism_platform" {
  name = var.domain_name

  tags = merge(
    var.tags,
    {
      "Name" = "${var.project_name}-route53-zone"
      "Project" = var.project_name
    }
  )
}

# Route53 Health Checks for each region
resource "aws_route53_health_check" "regional" {
  for_each = var.regions

  fqdn              = "api.${each.key}.${var.domain_name}"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(
    var.tags,
    {
      "Name" = "${var.project_name}-health-check-${each.key}"
      "Region" = each.key
      "Project" = var.project_name
    }
  )
}

# Route53 Record for Global API Endpoint (weighted routing)
resource "aws_route53_record" "api_global" {
  zone_id = aws_route53_zone.prism_platform.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  set_identifier = "global"

  alias {
    name                   = aws_cloudfront_distribution.api_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.api_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

# Route53 Regional API Records
resource "aws_route53_record" "api_regional" {
  for_each = var.regions

  zone_id        = aws_route53_zone.prism_platform.zone_id
  name           = "api.${each.key}.${var.domain_name}"
  type           = "A"
  set_identifier = each.key

  alias {
    name                   = each.value.api_endpoint
    zone_id                = each.value.api_zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.regional[each.key].id

  weighted_routing_policy {
    weight = each.value.routing_weight
  }
}

# Regional VPC Peering
resource "aws_vpc_peering_connection" "regional_peering" {
  for_each = {
    for pair in [
      for combo in setproduct(keys(var.regions), keys(var.regions)) : {
        src = combo[0],
        dst = combo[1]
      }
      if combo[0] != combo[1]
    ] : "${pair.src}-${pair.dst}" => pair
  }

  vpc_id      = var.regions[each.value.src].vpc_id
  peer_vpc_id = var.regions[each.value.dst].vpc_id
  peer_region = each.value.dst
  auto_accept = false

  tags = merge(
    var.tags,
    {
      "Name" = "${var.project_name}-vpc-peering-${each.value.src}-to-${each.value.dst}"
      "Project" = var.project_name
    }
  )
}

# Accept VPC Peering Connection
# This requires provider aliasing for each region
resource "aws_vpc_peering_connection_accepter" "regional_peering_accepter" {
  for_each = {
    for pair in [
      for combo in setproduct(keys(var.regions), keys(var.regions)) : {
        src = combo[0],
        dst = combo[1]
      }
      if combo[0] != combo[1]
    ] : "${pair.src}-${pair.dst}" => pair
  }

  provider = aws.regions[each.value.dst]

  vpc_peering_connection_id = aws_vpc_peering_connection.regional_peering["${each.value.src}-${each.value.dst}"].id
  auto_accept               = true

  tags = merge(
    var.tags,
    {
      "Name" = "${var.project_name}-vpc-peering-${each.value.src}-to-${each.value.dst}-accepter"
      "Project" = var.project_name
    }
  )
}

# Route Table Entries for VPC Peering
resource "aws_route" "regional_routes" {
  for_each = {
    for mapping in flatten([
      for pair_key, pair in {
        for pair in [
          for combo in setproduct(keys(var.regions), keys(var.regions)) : {
            src = combo[0],
            dst = combo[1]
          }
          if combo[0] != combo[1]
        ] : "${pair.src}-${pair.dst}" => pair
      } : [
        for route_table_id in var.regions[pair.src].private_route_table_ids : {
          pair_key = pair_key
          src = pair.src
          dst = pair.dst
          route_table_id = route_table_id
        }
      ]
    ]) : "${mapping.pair_key}-${mapping.route_table_id}" => mapping
  }

  route_table_id            = each.value.route_table_id
  destination_cidr_block    = var.regions[each.value.dst].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.regional_peering["${each.value.src}-${each.value.dst}"].id
}

# CloudFront Distribution for Global API Endpoint
resource "aws_cloudfront_distribution" "api_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Prism Platform Global API Distribution"
  default_root_object = ""
  price_class         = "PriceClass_All"

  # Set this to your domain name
  aliases = ["api.${var.domain_name}"]

  # Origin group for failover
  origin_group {
    origin_id = "all-origins"

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }

    member {
      origin_id = keys(var.regions)[0]
    }

    dynamic "member" {
      for_each = slice(keys(var.regions), 1, length(keys(var.regions)))
      content {
        origin_id = member.value
      }
    }
  }

  # Origins (one per region)
  dynamic "origin" {
    for_each = var.regions
    content {
      domain_name = "api.${origin.key}.${var.domain_name}"
      origin_id   = origin.key

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "all-origins"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Origin", "Authorization"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Viewer certificate
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.project_name}-cloudfront-distribution"
      "Project" = var.project_name
    }
  )
}

# DynamoDB Global Tables for shared state
resource "aws_dynamodb_table" "global_state" {
  provider = aws.primary_region

  name           = "${var.project_name}-global-state"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "id"
    type = "S"
  }

  replica {
    for_each = {for k, v in var.regions : k => v if k != var.primary_region}
    content {
      region_name = each.key
    }
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.project_name}-global-state"
      "Project" = var.project_name
    }
  )
}

# S3 Bucket for Shared Assets - primary region
resource "aws_s3_bucket" "shared_assets" {
  provider = aws.primary_region

  bucket = "${var.project_name}-shared-assets"

  tags = merge(
    var.tags,
    {
      "Name" = "${var.project_name}-shared-assets"
      "Project" = var.project_name
    }
  )
}

# S3 Bucket Replication Configuration
resource "aws_s3_bucket_replication_configuration" "shared_assets_replication" {
  provider = aws.primary_region

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.shared_assets.id

  dynamic "rule" {
    for_each = {for k, v in var.regions : k => v if k != var.primary_region}
    content {
      id = "replicate-to-${rule.key}"
      status = "Enabled"

      destination {
        bucket        = aws_s3_bucket.shared_assets_replica[rule.key].arn
        storage_class = "STANDARD"
      }
    }
  }
}

# S3 Bucket for Shared Assets - replica regions
resource "aws_s3_bucket" "shared_assets_replica" {
  for_each = {for k, v in var.regions : k => v if k != var.primary_region}

  provider = aws.regions[each.key]

  bucket = "${var.project_name}-shared-assets-${each.key}"

  tags = merge(
    var.tags,
    {
      "Name" = "${var.project_name}-shared-assets-${each.key}"
      "Project" = var.project_name
    }
  )
}

# IAM Role for S3 Replication
resource "aws_iam_role" "replication" {
  provider = aws.primary_region

  name = "${var.project_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for S3 Replication
resource "aws_iam_policy" "replication" {
  provider = aws.primary_region

  name = "${var.project_name}-s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.shared_assets.arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.shared_assets.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = values(aws_s3_bucket.shared_assets_replica)[*].arn
      }
    ]
  })
}

# Attach IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "replication" {
  provider = aws.primary_region

  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

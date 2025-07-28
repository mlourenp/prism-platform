variable "project_name" {
  description = "Name of the project, used for naming resources"
  type        = string
  default     = "prism-platform"
}

variable "domain_name" {
  description = "Root domain name for the application (e.g., prism-platform.com)"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "regions" {
  description = "Map of AWS regions with their configuration"
  type = map(object({
    vpc_id                 = string
    vpc_cidr               = string
    private_route_table_ids = list(string)
    api_endpoint           = string
    api_zone_id            = string
    routing_weight         = number
  }))
}

variable "primary_region" {
  description = "The primary AWS region where the main resources are deployed"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for CloudFront"
  type        = string
}

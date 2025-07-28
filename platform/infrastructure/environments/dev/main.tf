# /iac/terraform/environments/dev/main.tf

provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

module "data_lake" {
  source = "../../modules/s3_data_lake"

  bucket_name = "prism-platform-dev-data-lake"

  tags = {
    Environment = "dev"
  }
}

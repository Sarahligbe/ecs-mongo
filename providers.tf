provider "aws" {
    region = var.region
}

provider "mongodbatlas" {}

terraform {
    required_version = 
    required_providers {
        aws = {
            source = "harshicorp/aws"
            version = "~> 5.0"
        }
        mongodbatlas = {
        source = "mongodb/mongodbatlas"
        version = "1.26.0"
        }
    }
}
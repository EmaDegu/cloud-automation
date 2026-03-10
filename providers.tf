terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.6.0"
}

provider "aws" {
  region  = var.region
  profile = "terraform_user"
}


terraform {
  backend "s3" {
    bucket       = "cs1-terraform-s3"
    key          = "state/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = "terraform-locks"
    encrypt      = true
  }
}




#aws configure



#loki, grafana, prometheus, web server, vpn, NAT, autoscaling web
#account doe snot support creating a load balancer?

#C:\Users\Emilijos\.ssh\id_rsa.pub
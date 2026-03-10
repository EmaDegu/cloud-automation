variable "region" {
  type        = string
  description = "AWS main region"
  default     = "eu-central-1"
}

variable "profile" {
  type        = string
  description = "AWS CLI profile"
  default     = "client"
}


#instances types 
variable "instance_type_default" {
  type        = string
  description = "regular instance"
  default     = "t2.micro" #t3
}

variable "instance_type_monitor" {
  type        = string
  description = "Instance type for monitoring services - grafana, prometheus, loki"
  default     = "t2.micro" #t3
}


#vpc and its subnets
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  type    = string
  default = "10.0.0.0/20"
}

variable "public_subnet_b_cidr" {
  type    = string
  default = "10.0.16.0/20"
}

variable "app_subnet_a_cidr" {
  type    = string
  default = "10.0.32.0/20"
}

variable "app_subnet_b_cidr" {
  type    = string
  default = "10.0.48.0/20"
}




#security access control
variable "allowed_admin_ip" {
  type        = list(string)
  description = "allow admin ip for SSH access."
  default     = ["62.163.253.37/32"]
}


variable "public_key_path" {
  description = "Path to the SSH public key file"
  type        = string
}




#database 

variable "db_username" {
  type        = string
  description = "Database username for RDS"
  default     = "admin"
}

variable "db_password" {
  type        = string
  description = "Database password for RDS"
  sensitive   = true
  default     = "password123!"
}

variable "db_instance_class" {
  type        = string
  description = "Instance type for RDS"
  default     = "db.t2.micro" #t3
}

variable "db_engine" {
  default = "mysql"
}

variable "db_class" {
  default = "db.t3.micro"
}

variable "db_name" {
  default = "appdb"
}

variable "db_multi_az" {
  default = false
}


#variables for the web size 
variable "web_min_size" {
  default = 2
}

variable "web_desired_size" {
  default = 2
}

variable "web_max_size" {
  default = 4
}

#monitoring
variable "enable_monitoring_dns" {
  type    = bool
  default = false
}


#email for soar
variable "alert_email" {
  description = "Email to receive SOAR alerts"
  type        = string
}



variable "environment" {
  description = "Deployment environment ( test, prod)"
  type        = string
}

#nat security group
resource "aws_security_group" "sg_nat" {
  name        = "nat_sg"
  description = "NAT instance for the security groups"
  vpc_id      = aws_vpc.main.id


  ingress {
    description = "all tcp traffic from the vpc"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "all udp traffic from the vpc"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "all icmp traffic from the vpc"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "to ssh from the admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_admin_ip
  }

  egress {
    description = ""
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}





#web server security groups
resource "aws_security_group" "sg_web" {
  name        = "web-sg"
  description = "allow web traffic, HTTP, HTTPS, SSH from bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "to SSH from VPN security group"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_vpn.id]
  }

  ingress {
    description     = "to SSH from NAT security group"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_nat.id]
  }

  ingress {
    description     = "to HTTP from ALB security group"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_lb.id]
  }

  ingress {
    description     = "to HTTP from VPN security group"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_vpn.id]
  }

  egress {
    description = ""
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#VPN securoty group
resource "aws_security_group" "sg_vpn" {
  name        = "vpn_sg"
  description = "openVPN security group"
  vpc_id      = aws_vpc.main.id


  ingress {
    description = "openVPN udp "
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = var.allowed_admin_ip
  }

  ingress {
    description = "SSH to the VPN instance for admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_admin_ip
  }
  egress {
    description = ""
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }


}

#database security groups
resource "aws_security_group" "sg_db" {
  name        = "db-sg"
  description = "allow HTTP, HTTPS, SSH"
  vpc_id      = aws_vpc.main.id
}
resource "aws_security_group_rule" "db_inbound_mysql_app" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_db.id
  source_security_group_id = aws_security_group.sg_web.id
}

resource "aws_security_group_rule" "db_inbound_mysql_vpn" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_db.id
  source_security_group_id = aws_security_group.sg_vpn.id
}

resource "aws_security_group_rule" "db_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.sg_db.id
  cidr_blocks       = ["0.0.0.0/0"]
}



#security groups for monitoring
resource "aws_security_group_rule" "monitoring_inbound_grafana" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_monitoring.id
  source_security_group_id = aws_security_group.sg_web.id
}

resource "aws_security_group_rule" "monitoring_inbound_prometheus" {
  type                     = "ingress"
  from_port                = 9090
  to_port                  = 9090
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_monitoring.id
  source_security_group_id = aws_security_group.sg_web.id
}

resource "aws_security_group_rule" "monitoring_inbound_loki" {
  type                     = "ingress"
  from_port                = 3100
  to_port                  = 3100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_monitoring.id
  source_security_group_id = aws_security_group.sg_web.id
}



#load balancer security groups
resource "aws_security_group" "sg_lb" {
  name        = "lb-sg"
  description = "allow HTTP, HTTPS, SSH from the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



#monitoring for security group
resource "aws_security_group" "sg_monitoring" {
  name        = "monitoring_sg"
  description = "monitoring - prometheus, grafna, loki"
  vpc_id      = aws_vpc.main.id


  ingress {
    description     = "to SSH from VPN security group"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_vpn.id]
  }

  ingress {
    description     = "grafana from vpn security group"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_vpn.id]
  }


  ingress {
    description     = "prometheus from the vpn security group"
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_vpn.id]
  }

  ingress {
    description     = "loki from the vpn security group"
    from_port       = 3100
    to_port         = 3100
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_vpn.id]
  }

  egress {
    description     = ""
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web.id]
  }

  egress {
    description = ""
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


}


#instance isolation
resource "aws_security_group" "sg_quarantine" {
  name        = "sg-quarantine"
  description = "Blocks all inbound; minimal outbound"
  vpc_id      = aws_vpc.main.id

  # No ingress
  egress {
    description = "Deny all outbound by default? Keep minimal"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }
}







#alb           done
#nat           done
#vpn           done
#web app       done
#monitoring    slay?
#db            done

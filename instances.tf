#linux ami
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-ebs"]
  }
}


#nat
resource "aws_instance" "nat_a" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type_default
  subnet_id                   = aws_subnet.public_a.id
  associate_public_ip_address = true
  source_dest_check           = false
  user_data_replace_on_change = true
  security_groups             = [aws_security_group.sg_nat.id]
  vpc_security_group_ids      = [aws_security_group.sg_nat.id]

}
resource "aws_eip" "nat_a" {
  instance = aws_instance.nat_a.id
  domain   = "vpc"
}


resource "aws_instance" "nat_b" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type_default
  subnet_id                   = aws_subnet.public_b.id
  associate_public_ip_address = true
  source_dest_check           = false
  user_data_replace_on_change = true
  security_groups             = [aws_security_group.sg_nat.id]
  vpc_security_group_ids      = [aws_security_group.sg_nat.id]

}
resource "aws_eip" "nat_b" {
  instance = aws_instance.nat_b.id
  domain   = "vpc"
}


#vpn
resource "aws_instance" "vpn" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type_default
  subnet_id                   = aws_subnet.public_a.id
  associate_public_ip_address = true
  source_dest_check           = false
  user_data_replace_on_change = true
  security_groups             = [aws_security_group.sg_vpn.id]
  vpc_security_group_ids      = [aws_security_group.sg_vpn.id]

}
resource "aws_eip" "vpn" {
  instance = aws_instance.vpn.id
  domain   = "vpc"
}


#webservers a and b
resource "aws_instance" "web_a" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type_default
  subnet_id                   = aws_subnet.private_a.id
  security_groups             = [aws_security_group.sg_web.id]
  associate_public_ip_address = false
  user_data_replace_on_change = true
}


resource "aws_instance" "web_b" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type_default
  subnet_id                   = aws_subnet.private_b.id
  security_groups             = [aws_security_group.sg_web.id]
  associate_public_ip_address = false
  user_data_replace_on_change = true
}

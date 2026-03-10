# Route tables for web subnets
resource "aws_route_table" "web_a" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "web_b" {
  vpc_id = aws_vpc.main.id
}

# Associate web subnets with route tables
resource "aws_route_table_association" "web_a_assoc" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.web_a.id
}

resource "aws_route_table_association" "web_b_assoc" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.web_b.id
}



# Set up default routes for NAT instances
resource "aws_route" "web_a_default_nat_a" {
  route_table_id         = aws_route_table.web_a.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_a.primary_network_interface_id
  depends_on             = [aws_instance.nat_a]
}


resource "aws_route" "web_b_default_nat_b" {
  route_table_id         = aws_route_table.web_b.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_b.primary_network_interface_id
  depends_on             = [aws_instance.nat_b]
}


#the newer one
resource "aws_route" "web_b_default_nat_a" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_a.primary_network_interface_id
  depends_on             = [aws_instance.nat_a]
}



resource "aws_route" "web_a_vpn_clients" {
  route_table_id         = aws_route_table.web_a.id
  destination_cidr_block = "10.8.0.0/24"
  network_interface_id   = aws_instance.vpn.primary_network_interface_id
  depends_on             = [aws_instance.vpn]
}

resource "aws_route" "web_b_vpn_clients" {
  route_table_id         = aws_route_table.web_b.id
  destination_cidr_block = "10.8.0.0/24"
  network_interface_id   = aws_instance.vpn.primary_network_interface_id
  depends_on             = [aws_instance.vpn]

}
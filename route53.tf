# Private hosted zone
resource "aws_route53_zone" "internal" {
  name = "internal" # or "cs1.internal"
  vpc { vpc_id = aws_vpc.main.id }
}

# RDS private DNS (CNAME → RDS endpoint)
resource "aws_route53_record" "db_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "db.internal"
  type    = "CNAME"
  ttl     = 60
  records = [aws_db_instance.app_db.address]
}

# Web server private DNS (A → EC2 private IP)
resource "aws_route53_record" "web_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "web.internal"
  type    = "A"
  ttl     = 60
  records = [aws_instance.web_a.private_ip]
}


resource "aws_route53_record" "prometheus_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "prometheus.internal"
  type    = "A"
  ttl     = 60
  records = [aws_instance.prometheus.private_ip]
}

resource "aws_route53_record" "grafana_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "grafana.internal"
  type    = "A"
  ttl     = 60
  records = [aws_instance.grafana.private_ip]
}


#ALB - appliaction load balancer
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.sg_lb.id]

}



#alb listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_web.arn
  }
}

#targets 
resource "aws_lb_target_group_attachment" "web_a" {
  target_group_arn = aws_lb_target_group.tg_web.arn
  target_id        = aws_instance.web_a.id
  port             = 80
}


#resource "aws_lb_target_group_attachment" "web_b" {
# target_group_arn = aws_lb_target_group.tg_web.arn
#  target_id        = aws_instance.web_b.id
#  port             = 80
#}




#target group  for web servers with health checks
resource "aws_lb_target_group" "tg_web" {
  name        = "web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}


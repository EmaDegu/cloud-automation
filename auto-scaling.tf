resource "aws_launch_template" "web" {
  name_prefix            = "web"
  image_id               = data.aws_ami.al2.id
  instance_type          = var.instance_type_default
  vpc_security_group_ids = [aws_security_group.sg_web.id]
  user_data              = base64encode(file("user_data.sh"))
}

resource "aws_autoscaling_group" "web" {
  name_prefix         = "web-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.tg_web.arn]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}


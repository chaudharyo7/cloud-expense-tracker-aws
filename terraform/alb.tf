resource "aws_lb" "expense_alb" {
  name               = "expense-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}


resource "aws_lb_target_group" "expense_target_group_frontend" {
  name        = "expense-target-group-frontend"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group" "expense_target_group_backend" {
  name        = "expense-target-group-backend"
  target_type = "instance"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    path = "/api/health"
  }
}

resource "aws_lb_listener" "expense_listener_frontend" {
  load_balancer_arn = aws_lb.expense_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "expense_listener_https" {
  load_balancer_arn = aws_lb.expense_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.expense_target_group_frontend.arn
  }
}

resource "aws_lb_listener_rule" "expense_backend_rule_https" {
  listener_arn = aws_lb_listener.expense_listener_https.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.expense_target_group_backend.arn
  }
}


resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_lb_target_group_attachment" "expense_target_group_attachment_frontend" {
  target_group_arn = aws_lb_target_group.expense_target_group_frontend.arn
  target_id        = aws_instance.frontend_1.id
}
resource "aws_lb_target_group_attachment" "expense_target_group_attachment_frontend_2" {
  target_group_arn = aws_lb_target_group.expense_target_group_frontend.arn
  target_id        = aws_instance.frontend_2.id
}

resource "aws_lb_target_group_attachment" "expense_target_group_attachment_backend" {
  target_group_arn = aws_lb_target_group.expense_target_group_backend.arn
  target_id        = aws_instance.backend_1.id
}

resource "aws_lb_target_group_attachment" "expense_target_group_attachment_backend_2" {
  target_group_arn = aws_lb_target_group.expense_target_group_backend.arn
  target_id        = aws_instance.backend_2.id
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_http
  to   = aws_vpc_security_group_ingress_rule.alb_http["0.0.0.0/0"]
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_https
  to   = aws_vpc_security_group_ingress_rule.alb_https["0.0.0.0/0"]
}

moved {
  from = aws_lb_listener.https
  to   = aws_lb_listener.https[0]
}

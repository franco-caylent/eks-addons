# Wildcard record to point DNS to the LB
data "aws_route53_zone" "sigfig_internal" {
  provider     = aws.shared_services
  name         = "sigfig.internal."
  private_zone = true
}

data "aws_lb" "ingress_nlb" {
  tags = {
    "service.k8s.aws/stack" = "nginx-ingress/nginx-ingress-controller-ingress-nginx-controller"
    "elbv2.k8s.aws/cluster" = var.name
  }
  depends_on = [helm_release.nginx_ingress_controller]
}

resource "aws_route53_record" "wildcard" {
  count    = var.enable_nginx_ingress ? 1 : 0
  provider = aws.shared_services
  zone_id  = data.aws_route53_zone.sigfig_internal.zone_id
  name     = "*.${var.name}.eks.sigfig.internal"
  type     = "A"
  alias {
    name                   = data.aws_lb.ingress_nlb.dns_name
    zone_id                = data.aws_lb.ingress_nlb.zone_id
    evaluate_target_health = true
  }
}

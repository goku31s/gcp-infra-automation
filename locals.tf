locals {
  web_tag = "web-tiger"

  names = {
    network        = "${var.name_prefix}-vpc"
    subnet         = "${var.name_prefix}-subnet"
    router         = "${var.name_prefix}-router"
    nat            = "${var.name_prefix}-nat"
    fw_http_https  = "${var.name_prefix}-allow-http-https"
    fw_hc          = "${var.name_prefix}-allow-hc"
    instance_template = "${var.name_prefix}-instance-template"
    mig            = "${var.name_prefix}-mig"
    asg            = "${var.name_prefix}-autoscaler"
    hc             = "${var.name_prefix}-hc"
    backend        = "${var.name_prefix}-backend"
    urlmap         = "${var.name_prefix}-urlmap"
    proxy          = "${var.name_prefix}-proxy"
    forwarding_rule = "${var.name_prefix}-forwarding-rule"
  }
}


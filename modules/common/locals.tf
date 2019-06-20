locals {
  log_bucket_prefix = "${replace(var.root_domain_name,".","-dot-")}"
}


variable "region" {
  type    = "string"
  default = "us-east-1"
}

// root domain
variable "root_domain_name" {
  type    = "string"
  default = "cloudreach-NOT-VALID.com"
}

// www sub-domain
variable "www_domain_name" {
  type    = "string"
  default = "www.cloudreach-NOT-VALID.com"
}

// "origin" = the URL to be cached behind CloudFront
variable "target_origin" {
  type    = "string"
  default = "http://this-is-a-very-lengthy-url-that-is-NOT-VALID-AT-ALL.s3-website-us-northbynorthwest-1.amazonaws.com"
}

// For web sites behind CloudFront distributions, use "index.html", especially if the origin is a static page on S3
variable "default_root_object" {
  type    = "string"
  default = "index.html"
}

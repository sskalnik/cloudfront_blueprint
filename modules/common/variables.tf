variable "region" {
  type    = "string"
  default = "us-east-1"
}

// root domain
variable "root_domain_name" {
  type    = "string"
  default = "terraform-test-bucket.com"
}

// www sub-domain
variable "www_domain_name" {
  type    = "string"
  default = "www.terraform-test-bucket.com"
}

// "origin" = the URL to be cached behind CloudFront
variable "target_origin" {
  type    = "string"
  default = "this-is-a-very-lengthy-url-that-is-NOT-VALID-AT-ALL.s3-website-us-northbynorthwest-1.amazonaws.com"
}

// "index.html" or another default page/object to be delivered when a client requests the bare domain
variable "origin_root_object" {
  type    = "string"
  default = "index.html"
}

// Geo-restrictions per https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/georestrictions.html, if any
variable "geo_restriction_type" {
  type    = "string"
  default = "none"
}

variable "geo_restriction_locations" {
  type    = "list"
  default = []
}


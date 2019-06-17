// This Terraform template sets up a CloudFront distribution between a "human-friendly" domain (e.g., "cloudreach.com") and 
// an origin (e.g., "http://this-is-a-very-lengthy-url.s3-website-us-east-1.amazonaws.com").
//
// ACM is used for HTTPS certificate management. The cert is attached to the CloudFront distribution.
// Route53 is used for DNS. The hosted zone points to the CloudFront distribution.
// waf.tf sets up a basic WAF rate limiting rule, which is attached to the CloudFront distribution via a WAF ACL containing the rule.
//
// TODO: DNS validation options other than R53 + validation options other than DNS
// TODO: Take a list of domain names from the .tfvars input file, and create the appropriate CNAMEs and SNI records for each
//
// More info: https://www.terraform.io/docs/providers/aws/r/cloudfront_distribution.html#example-usage

provider "aws" {
  region = var.region
}

// ACM certs for CloudFront must be created in US East 1 at the time of writing
provider "aws" {
  alias  = "acm_region"
  region = "us-east-1"
}

data "aws_route53_zone" "root" {
  name = "${var.root_domain_name}."
}

// Create the "www." sub-domain within the root domain's Hosted Zone, as a CNAME pointing to the CloudFront distribution
resource "aws_route53_record" "domain_name" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "${var.www_domain_name}."
  type    = "CNAME"
  ttl     = "300"
  records = [aws_cloudfront_distribution.www_distribution.domain_name]
}

// Provision an ACM cert
resource "aws_acm_certificate" "cert" {
  domain_name               = var.root_domain_name
  validation_method         = "DNS"
  // For now just the "www." prefix, but could be expanded to a list of sub-domains as an input variable
  subject_alternative_names = [var.www_domain_name]
  lifecycle {
    create_before_destroy = true
  }
  provider = aws.acm_region
}

// Validate the cert for the root domain before proceeding to use it for CloudFront HTTPS traffic
resource "aws_route53_record" "cert_validation" {
  name    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.root.zone_id
  records = [aws_acm_certificate.cert.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

// Again for the "www." sub-domain
resource "aws_route53_record" "www_cert_validation" {
  name    = aws_acm_certificate.cert.domain_validation_options.1.resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options.1.resource_record_type
  zone_id = data.aws_route53_zone.root.zone_id
  records = [aws_acm_certificate.cert.domain_validation_options.1.resource_record_value]
  ttl     = 60
}

// The validation itself is a resource we can reference
// Waiting on the validation to exist, then referencing the validation instead of the cert, ensures that the cert is valid before we ever use it
resource "aws_acm_certificate_validation" "result" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [
    aws_route53_record.cert_validation.fqdn,
    aws_route53_record.www_cert_validation.fqdn,
  ]
  provider = aws.acm_region
  // If this takes more than 5 minutes, something is probably wrong. Set to 10 minutes to allow for leeway. Default is 45 minutes.
  timeouts {
    create = "10m"
  }
}

// Provision the CloudFront distribution
// Note that this step typically takes 15 minutes or more, e.g.:
// > aws_cloudfront_distribution.www_distribution: Creation complete after 23m42s [id=E25IP7Y7CE1Y8K]
resource "aws_cloudfront_distribution" "www_distribution" {
  // "origin" is AWS-speak for "target URL", i.e. what's behind Cloudfront and will be cached in the CloudFront distribution
  origin {
    // We need to set up a "custom" origin because otherwise CloudFront won't redirect traffic from the root domain to the www sub-domain
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      // If using an S3 origin, HTTP only; HTTPS is handled by the CloudFront distribution
      origin_protocol_policy = "http-only"
      // When anyone says "SSL" they really mean "the latest HTTPS protocol", which will be TLS
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

    // The origin URL
    domain_name = var.target_origin
    // This is just an arbitrary "tag" or "nickname"; that said, using the URL here reminds one of the URL redirect
    origin_id   = var.www_domain_name
  }

  // For web sites behind CloudFront distributions, use "index.html", especially if the origin is a static page on S3
  default_root_object = var.origin_root_object

  // All values are defaults from the AWS console:
  default_cache_behavior {
    // HTTPS only!
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    // Site is "read only"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    // This must match the "origin_id" value under "resource: origin: origin_id" above
    target_origin_id       = var.www_domain_name
    min_ttl                = 0
    // 1 day
    default_ttl            = 86400
    // 1 year
    max_ttl                = 31536000

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  // Include all CNAME values for which SNI should apply. See https://en.wikipedia.org/wiki/Server_Name_Indication
  aliases = [var.root_domain_name, var.www_domain_name]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  // Use an ACM cert for SSL/TLS
  viewer_certificate {
    // Use the ARN of the validated ACM cert
    acm_certificate_arn      = aws_acm_certificate_validation.result.certificate_arn
    // SNI is better than wildcard certs. See https://en.wikipedia.org/wiki/Server_Name_Indication
    ssl_support_method       = "sni-only"
    // See "origin_ssl_protocols"
    minimum_protocol_version = "TLSv1"
  }

  web_acl_id = aws_waf_web_acl.rate_limit_all_acl.id

  enabled = true
}

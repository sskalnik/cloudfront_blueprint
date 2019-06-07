// This Terraform template sets up a CloudFront distribution between a "human-friendly" domain (e.g., "cloudreach.com") and 
// an origin (e.g., "http://this-is-a-very-lengthy-url.s3-website-us-east-1.amazonaws.com").
// ACM is used for HTTPS.
// Route53 is used for DNS.
// TODO: DNS validation options other than R53 + validation options other than DNS
// More info: https://www.terraform.io/docs/providers/aws/r/cloudfront_distribution.html#example-usage

provider "aws" {
  region = "${var.region}"
}

resource "aws_route53_zone" "root" {
  name = "${var.root_domain_name}"
}

// Provision an ACM cert
resource "aws_acm_certificate" "cert" {
  domain_name       = "${var.root_domain_name}"
  validation_method = "DNS"
}

// Validate the cert before proceeding to use it for CloudFront HTTPS traffic
// Validation option 0 = DNS
resource "aws_route53_record" "validation" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${aws_route53_zone.root.zone_id}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = "60"
}

// The validation itself is a resource we can reference
// Waiting on the validation to exist, then referencing the validation instead of the cert, ensures that the cert is valid before we ever use it
resource "aws_acm_certificate_validation" "result" {
  certificate_arn = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = [
    "${aws_route53_record.validation.fqdn}",
  ]
}

// Provision the CloudFront distribution
resource "aws_cloudfront_distribution" "www_distribution" {
  // "origin" is AWS-speak for "target URL", i.e. what's behind Cloudfront and will be cached in the CloudFront distribution
  origin {
    // We need to set up a "custom" origin because otherwise CloudFront won't redirect traffic from the root domain to the www sub-domain
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "https-only"
      // When anyone says "SSL" they really mean "the latest HTTPS protocol", which will be TLS
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

    // The origin URL
    domain_name = "${var.target_origin}"
    // This is just an arbitrary "tag" or "nickname"; that said, using the URL here is a good idea
    origin_id   = "${var.www_domain_name}"
  }

  // For web sites behind CloudFront distributions, use "index.html", especially if the origin is a static page on S3
  default_root_object = "index.html"

  // All values are defaults from the AWS console:
  default_cache_behavior {
    // HTTPS only!
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    // Site is "read only"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    // This must match the "origin_id" value under "resource: origin: origin_id" above
    target_origin_id       = "${var.www_domain_name}"
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
  aliases = ["${var.target_origin}", "${var.www_domain_name}"]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  // Use an ACM cert for SSL/TLS
  viewer_certificate {
    // Use the ARN of the validated ACM cert
    acm_certificate_arn      = "${aws_acm_certificate_validation.result.certificate_arn}"
    // SNI is better than wildcard certs. See https://en.wikipedia.org/wiki/Server_Name_Indication
    ssl_support_method       = "sni-only"
    // See "origin_ssl_protocols"
    minimum_protocol_version = "TLSv1"
  }

  enabled = true
}

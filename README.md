# Overview

Just a Terraform recipe for AWS, plus some instructions on how to use the recipe, along with an explanation of the relevant best practices.

Given a "human-friendly" URL, such as "mysite.com", which may have a web sub-domain of "www.mysite.com"; and a less-human-friendly target origin such as "my-long-s3-bucket-name.s3.us-west-9000.amazonaws.com"; generate a CloudFront distribution that redirects traffic to HTTPS only, uses ACM for TLS and SNI, and uses Route53 for DNS-based validation. Cloudfront logs are sent to S3 and encrypted using a new KMS key specific to the log bucket. A new RSA key is generated, and the public key is uploaded to CloudFront for future use, e.g. for field-level encryption (the RSA private key can be exported for future use in the back-end application code to decrypt the fields). A basic "throttle DDoSes and traffic surges of 2000+ requests per 5 minutes" WAF rule is created, and attached to the CloudFront distribution via WAF ACL.

## Who is the target user?
The customers apropos this project are (a) any Cloudreach clients who need "typical best practices" applied to their AWS infrastructure, and (b) Cloudreach employees tasked with applying those "best practices", e.g. to an LZ, for the client.



# Pre-Requisites and Requirements

## Prerequisites
AWS account credentials necessary for Terraform to provision arbitrary resources

# Design
TBD

# Usage Guide
## Inputs
* Root/apex domain (e.g., example.com)
* Sub-domain for the web site (e.g., www.example.com)

## Outputs
* A per-apex-domain CloudFront distribution that handles HTTP-to-HTTPS redirection, as well as SSL/TLS termination
* A per-apex-domain ACM SSL/TLS certificate that utilizes SNI for all sub-domains
* A per-apex-domain S3 log bucket, with per-sub-domain prefixes (sub-folders) for each sub-domain's CloudFront logs
* A per-log-bucket KMS key providing server-side encryption
* A per-log-bucket lifecycle policy that transitions log files to Glacier after 30 days
* A per-apex-domain 2048-bit RSA key; the public key is uploaded to CloudFront and attached to the distribution for future use
* An AWS WAF ACL and rule that automatically throttles traffic surges and DDoSes per incoming IP (applied to each individual apex domain and sub-domain)


# FAQ

## TODO
Add the option to input an arbitrary number of domains and sub-domains, repeating the "recipe" for each. Add the option to pull in "one-size-fits-most" block lists and regularly revise the WAF ACL. Automatically set up field-level encryption Profiles and Configs (Terraform does not appear to handle these constructs at this time).

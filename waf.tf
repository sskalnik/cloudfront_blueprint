// Pro tip: use this pattern in Powershell to hammer the site to test the rate limit:
// > 1..3000 | % {Invoke-WebRequest -Uri "https://your-web-site-name.whatever.xyz" -UseBasicParsing}
// You should see something like the following after 2000+ hits (takes just a couple of minutes):
// > 403 ERROR
// > The request could not be satisfied.
// > Request blocked. 
// > Generated by cloudfront (CloudFront)
// > Request ID: 9UELZDhkEtMDjnZSTRhVgW2FRbdmhb30bkn-GeNp3H0FTotUK0WycA==

resource "aws_waf_rate_based_rule" "rate_limit_all_rule" {
  name        = "rate_limit_all_rule"
  metric_name = "RateLimited2000"
  rate_key    = "IP"
  rate_limit  = 2000
}

// By default, allow any traffic. Rate limit any given IP that makes more than 2000 requests over a 5 minute window
resource "aws_waf_web_acl" "rate_limit_all_acl" {
  name        = "rate_limit_all_acl"
  metric_name = "RateLimitedAll"
  depends_on  = ["aws_waf_rate_based_rule.rate_limit_all_rule"]
  default_action {
    type = "ALLOW"
  }
  rules {
    action {
      type = "BLOCK"
    }

    priority = 1
    rule_id  = aws_waf_rate_based_rule.rate_limit_all_rule.id
    type     = "RATE_BASED"
  }
}
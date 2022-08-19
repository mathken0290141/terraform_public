variable "aws_access_key" {}
variable "aws_secret_key" {}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = "ap-northeast-1"
}

// (AWS CloudTrail) ログ長期保管のための設定（証跡の作成）【MUST】

data "aws_caller_identity" "current" {}

resource "aws_cloudtrail" "rakulogi" {
  name                          = "tf-trail-rakulogi"
  s3_bucket_name                = aws_s3_bucket.rakulogi.id 
  s3_key_prefix                 = "prefix"
  include_global_service_events = false
  is_multi_region_trail = true
}

resource "aws_s3_bucket" "rakulogi" { //2つ目の""はS3のバケット名を表すので適宜変更してください
  bucket        = "tf-rakulogi-trail"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "rakulogi" {
  bucket = aws_s3_bucket.rakulogi.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "${aws_s3_bucket.rakulogi.arn}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "${aws_s3_bucket.rakulogi.arn}/prefix/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}
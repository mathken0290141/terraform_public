variable "aws_access_key" {}
variable "aws_secret_key" {}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = "ap-northeast-1"
}

# "rakulogi"となっている箇所を適宜ご変更ください

# (AWS CloudTrail) ログ長期保管のための設定（証跡の作成）【MUST】
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail

data "aws_caller_identity" "current" {}

resource "aws_cloudtrail" "rakulogi" {
  name                          = "tf-trail-rakulogi"
  s3_bucket_name                = aws_s3_bucket.rakulogi.id 
  s3_key_prefix                 = "prefix"
  include_global_service_events = false 
  # (AWS CloudTrail) CloudTrail Insights の有効化【SHOULD】
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail#insight_selector

  insight_selector{
    insight_type="ApiCallRateInsight"
  }
}

resource "aws_s3_bucket" "rakulogi" { 
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

# (AWS Config) 有効化（レコーダーの作成）【MUST】
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder_status

resource "aws_config_configuration_recorder_status" "rakulogi" {
  name       = aws_config_configuration_recorder.rakulogi.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.rakulogi]
}

resource "aws_iam_role_policy_attachment" "a" {
  role       = aws_iam_role.r.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_s3_bucket" "b" {
  bucket = "awsconfig-rakulogi"
}

resource "aws_config_delivery_channel" "rakulogi" {
  name           = "rakulogi"
  s3_bucket_name = aws_s3_bucket.b.bucket
}

resource "aws_config_configuration_recorder" "rakulogi" {
  name     = "rakulogi"
  role_arn = aws_iam_role.r.arn
}

resource "aws_iam_role" "r" {
  name = "rakulogi-awsconfig"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "p" {
  name = "awsconfig-example"
  role = aws_iam_role.r.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.b.arn}",
        "${aws_s3_bucket.b.arn}/*"
      ]
    }
  ]
}
POLICY
}

# (AWS IAM (ルートユーザー)) アクセスキーの削除【MUST】
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key
resource "aws_iam_access_key" "root" {
  user    = aws_iam_user.root.name
  pgp_key = "keybase:some_person_that_exists"
}

resource "aws_iam_user" "root" {
  name = "root"
  path = "/system/"
}

resource "aws_iam_user_policy" "root_ro" {
  name = "test"
  user = aws_iam_user.root.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

output "secret" {
  value = aws_iam_access_key.root.encrypted_secret
}
resource "aws_iam_user" "test" {
  name = "test"
  path = "/test/"
}

resource "aws_iam_access_key" "test" {
  user = aws_iam_user.test.name
}

output "aws_iam_smtp_password_v4" {
  value = aws_iam_access_key.test.ses_smtp_password_v4
}
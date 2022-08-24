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

# (AWS IAM) IAM パスワードポリシーの設定【MUST】
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_password_policy

resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 10
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
}


# (AWS IAM) IAM ユーザー/グループの作成【MUST】

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group
resource "aws_iam_group" "developers" {
  name = "developers"
  path = "/users/"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group_membership

resource "aws_iam_group_membership" "team" {
  name = "tf-testing-group-membership"

  users = [
    aws_iam_user.user_one.name,
    aws_iam_user.user_two.name,
  ]

  group = aws_iam_group.developers.name
}

resource "aws_iam_user" "user_one" {
  name = "test-user"
}

resource "aws_iam_user" "user_two" {
  name = "test-user-two"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group_policy_attachment
# https://intellipaat.com/community/28131/how-do-you-add-a-managed-policy-to-a-group-in-terraform

resource "aws_iam_group_policy_attachment" "test-attach" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# (AWS IAM Access Analyzer)有効化（アナライザーの作成）【SHOULD】
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/accessanalyzer_analyzer


resource "aws_accessanalyzer_analyzer" "rakulogi" {
  analyzer_name = "rakulogi"
  type          = "ACCOUNT"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/accessanalyzer_archive_rule
resource "aws_accessanalyzer_archive_rule" "rakulogi" {
  analyzer_name = "rakulogi"
  rule_name     = "rakulogi-rule"

  filter {
    criteria = "condition.aws:UserId"
    eq       = ["userid"]
  }

  filter {
    criteria = "error"
    exists   = true
  }

  filter {
    criteria = "isPublic"
    eq       = ["false"]
  }
}

# (Amazon GuardDuty) 有効化【SHOULD】
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_detector
resource "aws_guardduty_detector" "rakulogi" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }
}

# (AWS Security Hub) 有効化【SHOULD】
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_standards_control

resource "aws_securityhub_account" "rakulogi" {}

resource "aws_securityhub_standards_subscription" "cis_aws_foundations_benchmark" {
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
  depends_on    = [aws_securityhub_account.rakulogi]
}

# (Amazon Detective) 有効化【SHOULD】
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/detective_graph

# ★時間立ってから有効化する
# resource "aws_detective_graph" "rakulogi" {
#   tags = {
#     Name = "rakulogi-detective-graph"
#   }
# }

# (Amazon VPC) デフォルト VPC の削除【SHOULD】
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_vpc
# https://discuss.hashicorp.com/t/destroy-default-vpc/2474/5
# https://dev.classmethod.jp/articles/terraform-aws-provider-version-4/#toc-4

resource "aws_default_vpc" "default" {
  force_destroy = true
}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "ap-northeast-1"

  force_destroy = true
}
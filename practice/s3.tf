// 実行するアカウント情報
provider "aws" {
  region = "ap-northeast-1"
}

/*
プライベートバケット
  外部公開しないバケット
*/

# [aws_s3_bucket | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)
# プライベートバケットの定義
resource "aws_s3_bucket" "private" {
  # bucketに指定するバケット名は
  #   全世界で一意にしなければならない
  #   DNSの命名規則に従う
  #     [DNS 命名規則 (N1 Provisioning Server 3.1, Blades Edition Control Center 管理ガイド)](https://docs.oracle.com/cd/E19110-01/n1.provsrv.blades31/817-5734/FMG_CHP3_ACCOUNTS-5/)
  # という制約がある
  # [aws_s3_bucket | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket#bucket)
  bucket = "private-eg-terraform-terraform"

  # versioningの設定を有効にすると、オブジェクトを変更・削除しても、いつでも以前のバージョンへ復元できるようになる。
  # 多くのユースケースで有益な設定
  # [aws_s3_bucket | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket#using-versioning)
  versioning {
    enabled = true
  }

  /*
    暗号化を有効する
    有効にすると、オブジェクト保存時に自動で暗号化し、オブジェクト参照時に自動で復号するようになる。
    使い勝手が悪くなることもなく、デメリットがほぼない。
  */
  # サーバーサイド暗号化の設定
  #   [aws_s3_bucket_server_side_encryption_configuration | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration)
  server_side_encryption_configuration {
    # サーバーサイド暗号化のルール
    # [aws_s3_bucket_server_side_encryption_configuration | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration#rule)
    rule {
      # [aws_s3_bucket_server_side_encryption_configuration | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration#apply_server_side_encryption_by_default)
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

/*
ブロックパブリックアクセス
  設定すると、予期しないオブジェクトの公開を抑止できる。
  既存の公開設定の削除や、新規の公開設定をブロックするなど細かく設定できる。
  特に理由がなければ、すべての設定を有効にする。
  [aws_s3_account_public_access_block | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_account_public_access_block)
*/
# ブロックパブリックアクセスの定義
resource "aws_s3_bucket_public_access_block" "name" {
  bucket = aws_s3_bucket.private.id
  # AmazonS3がこのバケットのパブリックACLをブロックする
  #   ACLとは[ネットワーク ACL を使用してサブネットへのトラフィックを制御する - Amazon Virtual Private Cloud](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/vpc-network-acls.html)
  block_public_acls = true
  # AmazonS3がこのバケットのパブリックバケットポリシーをブロックする
  block_public_policy = true
  # AmazonS3がこのバケットのパブリックACLを無視するかどうか
  ignore_public_acls = true
  # AmazonS3がこのバケットのパブリックバケットポリシーを制限する
  restrict_public_buckets = true
}

/*
パブリックバケット
　外部公開するパブリックバケット
    アクセス権はaclで設定。
    ACLのデフォルトは「private」で、S3バケットを作成したAWSアカウント以外からはアクセスできない。
    明示的に「public-read」を指定し、インターネットからの読み込みを許可する。
    CORS（Cross-Origin Resource Sharing）も設定可能。
    cors_ruleで許可するオリジンやメソッドを定義。
*/
resource "aws_s3_bucket" "public" {
  bucket = "public-eg-terraform-terraform"
  acl    = "public-read"

  # [aws_s3_bucket_cors_configuration | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration#cors_rule)
  cors_rule {
    allowed_origins = ["https://example.com"]
    allowed_methods = ["GET"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

/*
ログバケット
　AWSの各種サービスがログを保存するためのログバケットを作成する。
*/

# ALBのアクセスログ用バケットの作成。
resource "aws_s3_bucket" "alb_log" {
  bucket = "alb-log-eg-terraform-terraform"

  # daysで指定した日数を経過したファイルを自動的に削除し、無限にファイルが増えないようにする。
  # [aws_s3_bucket | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket#using-object-lifecycle)
  lifecycle_rule {
    enabled = true

    expiration {
      days = "180"
    }
  }
}

/*
バケットポリシー
　バケットポリシーで、S3バケットへのアクセス権を設定する。
  ALBのようなAWSのサービスから、S3へ書き込みを行う場合に必要。
*/
# パケットポリシーの定義
resource "aws_s3_bucket_policy" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id
  policy = data.aws_iam_policy_document.alb_log.json
}

data "aws_iam_policy_document" "alb_log" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.alb_log.id}/*"]

    /*
      ALBの場合は、AWSが管理しているアカウントから書き込む。
      書き込みを行うアカウントID（582318560864）を指定する。
      このアカウントIDはリージョンごとに異なる。
      [Enable access logs for your Classic Load Balancer - Elastic Load Balancing](https://docs.aws.amazon.com/ja_jp/elasticloadbalancing/latest/classic/enable-access-logs.html#attach-bucket-policy)
    */
    principals {
      type        = "AWS"
      identifiers = ["582318560864"]
    }
  }
}

/*
S3バケットの削除
　S3バケットを削除する場合、バケット内が空になっていることを確認する。
  バケット内にオブジェクトが残っていると、destroyコマンドで削除できない。
  しかし、オブジェクトが残っていても、Terraformで強制的に削除する方法はあり、
　force_destroyをtrueにして一度applyする。
  applyするとオブジェクトが残っていても、destroyコマンドでS3バケットを削除できるようになる。
*/
resource "aws_s3_bucket" "force_destroy" {
  bucket        = "force-destroy-eg-terraform-terraform"
  force_destroy = true
}
/*
*/

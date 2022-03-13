# Terraform関連のバージョンを指定する
# [TerraformのAWS Provider v4メジャーアップデートは破壊的変更あり - Qiita](https://qiita.com/Shoyu_N/items/871ebf0c1d41493c22ac)
# [Terraformの使用バージョンを固定する - Qiita](https://qiita.com/ume3_/items/c35432902f7f7b99944c)
# [Terraformバージョンを固定する - Terraformのきほんと応用](https://zenn.dev/sway/articles/terraform_staple_fixversion)
terraform {
  # terraform自体のバージョン設定
  required_version = ">= 0.12"
  # AWS Providerのバージョン指定
  #   4.0で破壊的な変更あり
  required_providers {
    # source = "hashicorp/aws"
    aws = "~> 3.74.0"
  }
}

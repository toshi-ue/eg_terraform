# データソースを使用して外部データを参照する
# データソースを使うと外部データを参照できる
# e.g. 最新の Amazon Linux2のAMIを参照する
data "aws_ami" "recent_amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.????????-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "example" {
  ami           = data.aws_ami.recent_amazon_linux_2.image_id
  instance_type = "t3.micro"
}

# 他にも以下のような例などがある
# [Terraformでもいつでも最新AMIからEC2を起動したい | DevelopersIO](https://dev.classmethod.jp/articles/launch-ec2-from-latest-ami-by-terraform/)
# [データリソースとは - Terraform for さくらのクラウド(v1)](https://docs.usacloud.jp/terraform-v1/configuration/resources/data_resource/)
# [Terraform - データソース:aws_ami - このデータソースを使用して、他のリソースで使用するために登録されたAMIのIDを取得します。 使用例 引数参照 most_recent -（オプション）複数の結 - 日本語](https://runebook.dev/ja/docs/terraform/providers/aws/d/ami#executable_users)

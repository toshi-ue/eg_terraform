# 参照
# 作成するEC2インスタンスでApacheにアクセスできるようにセキュリティグループを定義、参照できるようにする
resource "aws_security_group" "example_ec2" {
  name = "example-ec2"

  # [aws_default_security_group | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group)
  # ingress を指定することで、セキュリティグループとインバウンドルールを作成できる。
  # [Terraformで1つのセキュリティグループに複数のルールを設定する - Qiita](https://qiita.com/Canon11/items/c1ee988516a6492dfb74#aws_security_group%E3%82%92%E6%9B%B8%E3%81%8F)
  # inbound 側のセキュリティ指定
  # [TerraformでAWS(EC2)のセキュリティグループを管理 - Qiita](https://qiita.com/zembutsu/items/5de875ed99ac8a56a998#%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%E3%82%B0%E3%83%AB%E3%83%BC%E3%83%97%E3%81%AE%E5%AE%9A%E7%BE%A9%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E3%82%92%E4%BD%9C%E6%88%90)
  # インバウンドのルールを作成
  ingress {
    # 開始ポート
    from_port = 80
    # 終了ポート
    to_port = 80
    # プロトコル
    protocol = "tcp"
    # 許可する CIDR
    cidr_blocks = ["0.0.0.0/0"]
  }

  # [TerraformでSecurity Groupを作ったら上手くいかなかった | DevelopersIO](https://dev.classmethod.jp/articles/my-mistake-about-creating-sg-by-terraform/)
  # アウトバウンドのルールを作成
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

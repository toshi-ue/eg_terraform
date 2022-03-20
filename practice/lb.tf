/*
HTTP用ロードバランサー
  HTTPアクセス可能なALBを作成する。
  ALBを配置するネットワークはnetwork.tfを使用する。

アプリケーションロードバランサー
　最初にアプリケーションロードバランサーを、リスト8.1のように定義します。
*/

resource "aws_lb" "example" {
  # 名前はnameで設定
  name = "example"
  # 種別をload_balancer_typeで設定
  # ALBやNLB (Network Load Balancer)を作成できる。
  # 「application」を指定するとALB、「network」を指定するとNLBになる。
  load_balancer_type = "application"
  # ALBが「インターネット向け」なのか「VPC内部向け」なのかを指定する。
  # インターネット向けの場合は、internalをfalseにする。
  internal = false
  # タイムアウト
  # 秒単位で指定する。タイムアウトのデフォルト値は60秒。
  idle_timeout = 60
  # 削除保護
  # trueにすると、削除保護が有効になる。本番環境では誤って削除しないよう、有効にしておく。
  # テストするときには必要ないためコメントアウトする
  # enable_deletion_protection = true

  /*
サブネット
　ALBが所属するサブネットをsubnetsで指定する。
  異なるアベイラビリティゾーンのサブネットを指定して、クロスゾーン負荷分散を実現する。
*/
  subnets = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id,
  ]

  /*
アクセスログ
  access_logsにバケット名を指定すると、アクセスログの保存が有効になる。
  s3.tf で作成したS3バケットを指定する。
*/
  access_logs {
    bucket  = aws_s3_bucket.alb_log.id
    enabled = true
  }

  security_groupts = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.http_redirect_sg.security_group.id,
  ]
}

output "alb_dns_name" {
  value = aws_lb.example.dns_name
}

/*
セキュリティグループ
  HTTPの80番ポートとHTTPSの443番ポートに加えて、HTTPのリダイレクトで使用する8080番ポートも許可する。
  security_groupsに、これらのセキュリティグループを設定する。
*/
module "http_sg" {
  # security_groupフォルダの設定を参照
  source = "./security_group"
  name   = "http-sg"
  vpc_id = aws_vpc.example.id
  # HTTPのポート番号
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source = "./security_group"
  name   = "https-sg"
  vpc_id = aws_vpc.example.id
  # HTTPのポート番号
  port        = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source = "./security_group"
  name   = "https-redirect-sg"
  vpc_id = aws_vpc.example.id
  # HTTPのリダイレクトで使用するポート番号
  port        = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

/*
リスナー
  リスナーで、どのポートのリクエストを受け付けるか設定。
  リスナーはALBに複数アタッチできる。
  [aws_lb_listener | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)
*/
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  /*
  ポート番号
    portには1～65535の値が設定できる。
    HTTPなので「80」を指定。
  */
  port = "80"
  /*
  プロトコル
  　ALBは「HTTP」と「HTTPS」のみサポートしている。
    protocolで指定。
  */
  protocol = "HTTP"

  /*
デフォルトアクション
　リスナーは複数のルールを設定して、異なるアクションを実行できる。
  いずれのルールにも合致しない場合は、default_actionが実行される。
  定義できるアクションにはいくつかある本書では3つ紹介します。
　・forward ： リクエストを別のターゲットグループに転送
　・fixed-response ： 固定のHTTPレスポンスを応答
　・redirect ： 別のURLにリダイレクト
  その他は[aws_lb_listener | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener#default_action)で確認できる
　ここでは固定のHTTPレスポンスを設定している。
*/
  default_action {
    type = "fixed-response"

    fixed_response {
      contencontent_type = "text/plain"
      message_body       = "これは HTTP です"
      status_code        = "200"
    }
  }
}







/*
*/
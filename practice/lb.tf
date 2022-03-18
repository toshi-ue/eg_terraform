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
  enable_deletion_protection = true

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
*/

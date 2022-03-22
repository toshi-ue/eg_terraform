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

  security_groups = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.http_redirect_sg.security_group_id,
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
  # security_groupフォルダの設定を参照(?)
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
  name   = "http-redirect-sg"
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
      content_type = "text/plain"
      message_body = "これは HTTP です"
      status_code  = "200"
    }
  }
}

/*
Route 53
  Route 53は、AWSが提供するDNS (Domain Name System)のサービス。

  ドメインの登録
    AWSマネジメントコンソールから次の手続きを行うと、ドメインの登録ができる。
    １．ドメイン名の入力
    ２．連絡先情報の入力
    ３．登録メールアドレスの有効性検証
    ドメインの登録は、Terraformでは実行できない。
  ホストゾーン
    DNSレコードを束ねるリソース。
    Route 53でドメインを登録した場合は、自動的に作成される。
    同時にNSレコードとSOAレコードも作成される。
      NSレコード ：管理を委託しているDNSサーバの名前が書かれている行
      SOAレコード：DNSで定義されるそのドメインについての情報の種類の１つで、ゾーンの管理のための情報や設定などを記述するためのもの
    「example.com」を登録した前提でコードを記述する。
  [aws_route53_zone | Data Sources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone)
  [aws_route53_zone | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone)
*/
# ホストゾーンの参照
# ホストゾーンのデータソースの定義
data "aws_route53_zone" "example" {
  # TODO: 変更してapplyを試す
  name = "example.com"
}

# ホストゾーンの作成
resource "aws_route53_zone" "test_example" {
  # TODO: 変更してapplyを試す
  name = "test.example.com"
}

/*
DNSレコード
  設定したドメインでALBへとアクセスできるようになる。
*/
resource "aws_route53_record" "example" {
  zone_id = data.aws_route53_zone.example.zone_id
  name    = data.aws_route53_zone.example.name
  /*
    DNSレコードタイプはtypeに設定。
    AレコードやCNAMEレコードなど、一般的なレコードタイプが指定可能。
    AWS独自拡張のALIASレコードを使用する場合は、Aレコードをあらわす「A」を指定する。
  */
  type = "A"

  /*
    ALIASレコードは、AWSでのみ使用可能なDNSレコード。
    DNSからみると、単なるAレコードという扱いになる。
    Aレコード(ALIASレコード)は、AWSの各種サービスと統合されており、ALBだけでなくS3バケットやCloudFrontも指定できる。
  　CNAMEレコードは「ドメイン名→CNAMEレコードのドメイン名→IPアドレス」という流れで名前解決を行う。
    Aレコードは「ドメイン名→IPアドレス」という流れで名前解決が行われ、パフォーマンスが向上する。
    aliasにALBのDNS名とゾーンIDを指定すると、ALBのIPアドレスへ名前解決できるようになります。
  */
  alias {
    name                   = aws_lb.example.dns_name
    zone_id                = aws_lb.example.zone_id
    evaluate_target_health = true
  }
}

output "donmain_name" {
  value = aws_route53_record.example.name
}

/*
ACM（AWS Certificate Manager）
  HTTPS化するために必要なSSL証明書を、ACM (AWS Certificate Manager)で作成する。
  ACMは煩雑なSSL証明書の管理を担ってくれるマネージドサービスで、ドメイン検証をサポートしている。
  SSL証明書の自動更新ができるため「証明書の更新忘れた！」という幾度となく人類が繰り返してきた悲劇から解放される。
  [aws_acm_certificate | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate)
*/
# SSL証明書の定義
resource "aws_acm_certificate" "example" {
  /*
    「*.example.com」のように指定すると、ワイルドカード証明書を発行できる。
  */
  domain_name = aws_route53_record.example.name
  /*
    ドメイン名を追加したい場合、subject_alternative_namesを設定する。
    たとえば["test.example.com"]と指定すると、「example.com」と「test.example.com」のSSL証明書を作成する。
    追加しない場合は、空リストを渡す。
  */
  subject_alternative_names = []
  /*
    ドメインの所有権の検証方法を、validation_methodで設定する。
    DNS検証かEメール検証を選択できる。
    SSL証明書を自動更新したい場合、DNS検証を選択する。
  */
  validation_method = "DNS"

  /*
    lifecycle定義で「新しいSSL証明書を作ってから、古いSSL証明書と差し替える」という挙動に変更し、SSL証明書の再作成時のサービス影響を最小化する。
    ライフサイクルはTerraform独自の機能で、すべてのリソースに設定可能。
    通常のリソースの再作成は「リソースの削除をしてから、リソースを作成する」という挙動になる。
    しかし、create_before_destroyをtrueにすると、「リソースを作成してから、リソースを削除する」という逆の挙動に変更できる。
  */
  lifecycle {
    create_before_destroy = true
  }
}


/*
SSL証明書の検証
  DNSによる、SSL証明書の検証もTerraformで実装できる。
  DNS検証用のDNSレコードを追加する。
  subject_alternative_namesにドメインを追加した場合、そのドメイン用のDNSレコードも必要になるので注意が必要。
  [aws_route53_record | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)
*/
# SSL証明書の検証
resource "aws_route53_record" "example_certificate" {
  name    = aws_acm_certificate.example.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.example.domain_validation_options[0].resource_record_type
  records = [aws_acm_certificate.example.domain_validation_options[0].resource_record_value]
  zone_id = data.aws_route53_zone.example.id
  ttl     = 60
}





/*
*/

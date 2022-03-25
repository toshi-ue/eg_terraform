/*
Webサーバーの構築
  ここでは、ECSをプライベートネットワークに配置し、nginxコンテナを起動する。
  ALB経由でリクエストを受け取り、それをECS上のnginxコンテナが処理する。
ECSクラスタ
  ECSクラスタは、Dockerコンテナを実行するホストサーバーを、論理的に束ねるリソースのこと。
  クラスタ名を指定するだけ。
*/
# ECSクラスタの定義
resource "aws_ecs_cluster" "example" {
  name = "example"
}









/*
*/
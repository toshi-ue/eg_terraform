/*
Webサーバーの構築
  ここでは、ECSをプライベートネットワークに配置し、nginxコンテナを起動する。
  ALB経由でリクエストを受け取り、それをECS上のnginxコンテナが処理する。
ECSクラスタ
  ECSクラスタは、Dockerコンテナを実行するホストサーバーを、論理的に束ねるリソースのこと。
  クラスタ名を指定するだけ。
*/
# ECSクラスタの定義
# [aws_ecs_cluster | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster)
resource "aws_ecs_cluster" "example" {
  name = "example"
}

/*
タスク定義
  コンテナの実行単位を「タスク」と呼ぶ。
  たとえば、Railsアプリケーションの前段にnginxを配置する場合、ひとつのタスクの中でRailsコンテナとnginxコンテナが実行される。
  そして、タスクは「タスク定義」から生成される。
  タスク定義では、コンテナ実行時の設定を記述する。
  オブジェクト指向言語でたとえると、タスク定義はクラスで、タスクはインスタンスになる。
  [aws_ecs_task_definition | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)
*/
# タスクの定義
resource "aws_ecs_task_definition" "example" {
  /*
    ファミリーとはタスク定義名のプレフィックスで、familyに設定する。
    ファミリーにリビジョン番号を付与したものがタスク定義名になる。
    以下の例の場合は最初は「example:1」となる。
    リビジョン番号は、タスク定義更新時にインクリメントされる。
  */
  family = "example"
  /*
  タスクサイズ
    cpuとmemoryで、タスクが使用するリソースのサイズを設定する。
    cpuはCPUユニットの整数表現（例：1024）か、vCPUの文字列表現（例：1 vCPU）で設定する。
    memoryはMiBの整数表現（例：1024）か、GBの文字列表現（例：1 GB）で設定する。
    設定できる値の組み合わせは決まっている。
    たとえばcpuに256を指定する場合、memoryで指定できる値は512・1024・2048のいずれかになる。
  */
  cpu    = "256"
  memory = "512"
  /*
  ネットワークモード
    Fargate起動タイプの場合は、network_modeに「awsvpc」を指定する。
  */
  network_mode = "awsvpc"
  /*
  起動タイプ
    requires_compatibilitiesに「Fargate」を指定する。
  */
  requires_compatibilities = ["FARGATE"]
  /*
  コンテナ定義
    「container_definitions.json」ファイルにタスクで実行するコンテナを定義する。
  */
  container_definitions = file("./container_definitions.json")
}















/*
*/

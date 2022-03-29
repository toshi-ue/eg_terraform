/*
Webサーバーの構築
  ここでは、ECSをプライベートネットワークに配置し、nginxコンテナを起動する。
  ALB経由でリクエストを受け取り、それをECS上のnginxコンテナが処理する。
ECSクラスタ
  ECSクラスタは、Dockerコンテナを実行するホストサーバーを、論理的に束ねるリソースのこと。
  クラスタ名を指定するだけ。

正常に設定ができているかどう確認するには
terraform applyを実行した後で。ブラウザから以下のアドレスにアクセスしてnginxのデフォルト画面が表示されればok
https://medcoolapp.com
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
  /*
    Dockerコンテナのロギング設定
      logConfiguration.logDriver：awslogs を指定する
      logConfiguration.options  ：aws_cloudwatch_log_groupの内容を設定していきます
      logConfiguration.options.awslogs-group：aws_cloudwatch_log_groupのnameを指定します
  */
  execution_role_arn = module.ecs_task_execution_role.iam_role_arn
}


/*
ECSサービス
  通常、コンテナを起動しても、処理が完了したらすぐに終了します。もちろん、Webサービスでそれは困るため、「ECSサービス」を使う。
  ECSサービスは起動するタスクの数を定義でき、指定した数のタスクを維持する。
  なんらかの理由でタスクが終了してしまった場合、自動的に新しいタスクを起動してくれる優れもの。
  また、ECSサービスはALBとの橋渡し役にもなる。
  インターネットからのリクエストはALBで受け、そのリクエストをコンテナにフォワードする。
  [aws_ecs_service | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)
*/
# ECSサービスの定義
resource "aws_ecs_service" "example" {
  name = "example"
  # clusterには、resource "aws_ecs_cluster" "example" で作成したECSクラスタを設定する。
  cluster = aws_ecs_cluster.example.arn
  #   resource "aws_ecs_task_definition" "example" で作成したタスク定義を設定する。
  task_definition = aws_ecs_task_definition.example.arn
  # ECSサービスが維持するタスク数はdesired_countで指定する。
  # 指定した数が1の場合、コンテナが異常終了すると、ECSサービスがタスクを再起動するまでアクセスできなくなる。
  # そのため本番環境では2以上を指定する。
  desired_count = 2
  # 起動タイプ
  # launch_typeには「FARGATE」を指定する。
  launch_type = "FARGATE"
  # プラットフォームバージョン
  # platform_versionのデフォルトは「LATEST」。
  # ただしLATESTはその名前に反して、最新のバージョンでない場合がある。
  # これはAWSの公式ドキュメント2にも記載されている仕様。
  #   [AWS Fargateプラットフォームのバージョン - Amazon Elastic Container Service](https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/platform_versions.html)
  # よって、バージョンは明示的に指定し、LATESTの使用は避ける。
  platform_version = "1.3.0"
  # ヘルスチェック猶予期間
  # health_check_grace_period_secondsに、タスク起動時のヘルスチェック猶予期間を設定する。
  # 秒単位で指定し、デフォルトは0秒。
  # タスクの起動に時間がかかる場合、十分な猶予期間を設定しておかないとヘルスチェックに引っかかり、
  #   タスクの起動と終了が無限に続いてしまうため、0以上の値にする。
  health_check_grace_period_seconds = 60

  # ネットワーク構成
  # network_configurationには、サブネットとセキュリティグループを設定する。
  # あわせて、パブリックIPアドレスを割り当てるか設定する。
  # resource "aws_ecs_service" "example" では、プライベートネットワークで起動するため、パブリックIPアドレスの割り当ては不要。
  network_configuration {
    assign_public_ip = false
    security_groups  = [module.nginx_sg.security_group_id]

    subnets = [
      aws_subnet.private_0.id,
      aws_subnet.private_1.id
    ]
  }

  # ロードバランサー
  # 　load_balancerでターゲットグループとコンテナの名前・ポート番号を指定し、ロードバランサーと関連付ける。
  #   container_definition.json との関係は以下のようになる。
  # 　・container_name ＝ コンテナ定義のname
  # 　・container_port ＝ コンテナ定義のportMappings.containerPort
  # 　なお、コンテナ定義に複数のコンテナがある場合は、最初にロードバランサーからリクエストを受け取るコンテナの値を指定する。
  load_balancer {
    target_group_arn = aws_lb_target_group.example.arn
    container_name   = "example"
    container_port   = 80
  }

  # ライフサイクル
  # 　Fargateの場合、デプロイのたびにタスク定義が更新され、plan時に差分が出る。
  #   よって、Terraformではタスク定義の変更を無視すべき。
  # 　そこで、ignore_changesを設定する。
  #   ignore_changesに指定したパラメータは、リソースの初回作成時を除き、変更を無視するようになる。
  lifecycle {
    ignore_changes = [task_definition]
  }
}

module "nginx_sg" {
  source      = "./security_group"
  name        = "nginx-sg"
  vpc_id      = aws_vpc.example.id
  port        = 80
  cidr_blocks = [aws_vpc.example.cidr_block]
}

/*
Fargateにおけるロギング
  Fargateではホストサーバーにログインできず、コンテナのログを直接確認できない。
  そのためCloudWatch Logsと連携し、ログを記録できるようにする。
CloudWatch Logs
  CloudWatch Logsはあらゆるログを収集できるマネージドサービス。
  AWSの各種サービスと統合されており、ECSもそのひとつ。
  CloudWatch Logsは以下のように定義する。
  [aws_cloudwatch_log_group | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)
*/
# CloudWatch Logsの定義
resource "aws_cloudwatch_log_group" "for_ecs" {
  name = "/ecs/example"
  # retention_in_daysで、ログの保持期間を指定する
  retention_in_days = 180
}

/*
ECSタスク実行IAMロール
  ECSに権限を付与するため、ECSタスク実行IAMロールを作成する。
IAMポリシーデータソース
  「AmazonECSTaskExecutionRolePolicy」はAWSが管理しているポリシー。
  ECSタスク実行IAMロールでの使用が想定されており、CloudWatch LogsやECRの操作権限を持っている。
  以下のように、aws_iam_policyデータソースを使って参照できる。
  [aws_iam_policy | Data Sources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy)
*/

# AmazonECSTaskExecutionRolePolicyの参照
data "aws_iam_policy" "ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

/*
ポリシードキュメント
  ポリシードキュメントを以下のように定義する。
  [aws_iam_policy_document | Data Sources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)
*/

# ECSタスク実行IAMロールのポリシードキュメントの定義
data "aws_iam_policy_document" "ecs_task_execution" {
  # source_json を使うと既存のポリシーを継承できる
  # ここではAmazonECSTaskExecutionRolePolicyを継承し、 SSMパラメータストアとECSの統合 で必要な権限を先行して追加する。
  source_json = data.aws_iam_policy.ecs_task_execution_role_policy.policy

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters", "kms:Decrypt"]
    resources = ["*"]
  }
}

/*
IAMロール
  iam_roleモジュール(iam_role/main.tf)を利用して、以下のようにIAMロールを作成する。
  identifierには「ecs-tasks.amazonaws.com」を指定し、このIAMロールをECSで使うことを宣言する。
*/
# ECSタスク実行IAMロールの定義
module "ecs_task_execution_role" {
  source     = "./iam_role"
  name       = "ecs-task-execution"
  identifier = "ecs-tasks.amazonaws.com"
  policy     = data.aws_iam_policy_document.ecs_task_execution.json
}



/*
*/

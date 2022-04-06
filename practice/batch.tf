/*
  バッチ
    バッチ処理は、オンライン処理とは異なる関心事を有している
    アプリケーションレベルでどこまで制御し、ジョブ管理システムでどこまでサポートするかはしっかり設計する必要があります
    ＜バッチ設計の基本原則＞
      以下の４つの原則がある
        ジョブ管理
        エラーハンドリング
        リトライ
        依存関係制御

      ジョブ管理
        バッチは一定の周期で実行されますが、誰かがジョブの起動タイミングを制御しなければなりません。
        それがジョブ管理です。ジョブ管理は、バッチ処理では重要な関心事です。ジョブ管理の仕組みに問題が発生すると、
        最悪の場合、全ジョブが停止します。
        cron や ジョブ管理システム（RundeckやJPI）などを使用する
          cron　　　　　　　：依存関係制御もできず、cronを動かすサーバーの運用にも手間がかかる
          ジョブ管理システム：エラー通知やリトライ、依存関係制御の仕組みが組み込まれており、複雑なジョブの管理ができる、稼働させるサーバーの運用は課題として残る
      エラーハンドリング
        エラーハンドリングでは「エラー通知」が重要です
        なんらかの理由でバッチが失敗した場合、それを検知してリカバリーする必要があります
        またエラー発生時の「ロギング」も重要、スタックトレースなどの情報は、原因調査で必要になるため、確実にログ出力します
      リトライ
        バッチ処理が失敗した場合、リトライできなければなりません。自動で指定回数リトライできることが望ましい
        少なくとも、手動ではリトライできる必要がある
        リトライできるようアプリケーションを設計する必要があります
      依存関係制御
        ジョブが増えてくると依存関係制御が必要になります
        「ジョブAは必ずジョブBのあとに実行しなければならない」などはよくあります。単純に時間をずらして
        暗黙的な依存関係制御を行う場合もありますが、アンチパターンなので避けましょう。
 */

/*
ECS Scheduled Tasks
  AWSにはジョブ管理システムのマネージドサービスはそんざいしない。
  つまり、システムが大きくなるとジョブ管理システムの導入は避けられない。
  しかし、ある程度の規模までであれば「ECS Scheduled Tasks」を使うことで、ジョブ管理システムの導入を先送りできる。
  ECS Scheduled Tasksは、ECSのタスクを定期実行する。
  実装は単純で、CloudWatchイベントからタスクを起動するだけ。
  ECS Scheduled Tasks単体では、エラーハンドリングやリトライはアプリケーションレベルで実装する必要があり、依存関係制御もできない。
  しかし、ジョブ管理サーバーを運用する必要がなく、cronよりもはるかにメンテナンス性が向上する。
バッチ用CloudWatch Logs
  複数のバッチで使いまわすこともできるが、バッチごとに作成したほうが運用は楽。
*/
# バッチ用CloudWatch Logsの定義
resource "aws_cloudwatch_log_group" "for_ecs_scheduled_tasks" {
  name              = "/ecs-scheduled-tasks/example"
  retention_in_days = 180
}

# バッチ用タスク定義
resource "aws_ecs_task_definition" "example_batch" {
  family                   = "example-batch"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./batch_container_definitions.json")
  execution_role_arn       = module.ecs_task_execution_role.iam_role_arn
}

/*
バッチ用コンテナ定義
  コンテナ定義を「batch_container_definitions.json」というファイルに実装する。
  時を刻むステキなバッチ。
*/
# バッチ用コンテナ定義
# [
#   {
#     "name": "alpine",
#     "image": "alpine:latest",
#     "essential": true,
#     "logConfiguration": {
#       "logDriver": "awslogs",
#       "options": {
#         "awslogs-region": "ap-northeast-1",
#         "awslogs-stream-prefix": "batch",
#         "awslogs-group": "/ecs-scheduled-tasks/example"
#       }
#     },
#     "command" : ["/bin/date"]
#   }
# ]

/*
CloudWatchイベントIAMロール
  以下のように、CloudWatchイベントからECSを起動するためのIAMロールを作成する。
  AWSが管理している「AmazonEC2ContainerServiceEventsRole」ポリシーを使うと簡単。
  このポリシーでは「タスクを実行する」権限と「タスクにIAMロールを渡す」権限を付与する。
*/
# CloudWatchイベントIAMロールの定義
module "ecs_events_role" {
  source     = "./iam_role"
  name       = "ecs-events"
  identifier = "events.amazonaws.com"
  policy     = data.aws_iam_policy.ecs_events_role_policy.policy
}

data "aws_iam_policy" "ecs_events_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

/*
*/
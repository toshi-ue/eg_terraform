/*
ポリシー
  権限はポリシーで定義する
  ポリシーでは「実行可能なアクション」や「操作可能なリソース」を指定でき、柔軟に権限が設定できる
ロール
  AWSのサービスへ権限を付与するために、「IAMロール」を作成
IAMロールのモジュール化
*/

variable "name" {}       // IAMロールとIAMポリシーの名前
variable "policy" {}     // ポリシードキュメント
variable "identifier" {} // IAMロールを関連づけるAWSのサービス識別子

/*
IAMロールの定義。
信頼ポリシーとロール名を指定する
*/
resource "aws_iam_role" "default" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

/*
ポリシードキュメント
JSON でも tf でも記述できる
JSONの場合 は以下のように記述する
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["ec2:DescribeRegions"],
        "Resource": ["*"]
      }
    ]
  }
tfの場合以下のように記述する
  data "aws_iam_policy_document" "allow_describe_regions" {
    statement {
      effect    = "Allow"
      actions   = ["ec2:DescribeRegions"] # リージョン一覧を取得する
      resources = ["*"]
    }
  }
aws_iam_policy_documentデータソースでもポリシーを記述できる。コメントの追加や変数の参照ができて便利。
ポリシードキュメントでは、Effect, Action, Resourceを定義する
  Effect ： Allow（許可）またはDeny（拒否）
  Action ： なんのサービスで、どんな操作が実行できるか
  Resource ： 操作可能なリソースはなにか
　リスト5.1は「リージョン一覧を取得する」という権限を意味します。なお、7行目の『*』は扱いが特殊で「すべて」という意味になります。
　リスト5.2のようにaws_iam_policy_documentデータソースでもポリシーを記述できます。コメントの追加や変数の参照ができて便利です。
*/

/*
信頼ポリシー
  IAMロールでは、自身をなんのサービスに関連付けるか宣言する必要があり、その宣言は「信頼ポリシー」と呼ばれる。
  AWSのサービスへの権限を付与するIAMロールの記述
    data "aws_iam_policy_document" "ec2_assume_role" {
      statement {
        actions = ["sts:AssumeRole"]
    
        principals {
          type        = "Service"
          identifiers = ["ec2.amazonaws.com"] // ec2のみ関連付けが可能になる設定
        }
      }
    }
*/
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    /*
    AWS リソースのアクションまたはオペレーションに対してリクエストできるユーザーまたはアプリケーションを指す。
    プリンシパルは、AWS アカウント のルートユーザー または IAM エンティティとして認証され、AWS にリクエストを行うことができる。
    [IAM の仕組みについて - AWS Identity and Access Management](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/intro-structure.html)
    */
    principals {
      type        = "Service"
      identifiers = [var.identifier]
    }
  }
}

/*
IAMポリシー
  ポリシードキュメントを保持するリソース
*/
resource "aws_iam_policy" "default" {
  name   = var.name
  policy = var.policy
}

/*
IAMロールにIAMポリシーをアタッチ
  IAMロールとIAMポリシーは、関連付けないと機能しない
*/
resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.default.arn
}

/*
ARNとは
  アマゾン・リソース・ネーム（Amazon Resource Name）の略。
  個々のAWSリソースに割り当てられた一意の識別子。
  ARNは、グローバルでユニークな意識別子。
  IAM ポリシー、API呼び出しなど、全AWSに渡るリソースを指定する必要がある場合、ARNが必要となる
  [コンサルティング用語集 | ARNとは](https://consulting-glossary.com/item.php?name=ARN)
*/
output "iam_role_arn" {
  value = aws_iam_role.default.arn
}

output "iam_role_name" {
  value = aws_iam_role.default.name
}
/*
その他参考
ec2:DescribeRegionsとは
  AWSのEC2の権限の設定
  [IAMのEC2権限をまとめてみた - サーバーワークスエンジニアブログ](https://blog.serverworks.co.jp/tech/2014/02/07/iam-ec2/)
sts:AssumeRoleとは
  AWS Security Token Service (AWS STS) に対するAPIアクションの一つ。以下を参考にすると理解できそう
  [AWS STSとは？IAMユーザーとの違いと使い方について紹介！FEnet AWSコラム](https://www.fenet.jp/aws/column/tool/1765/)
  [IAMロール徹底理解 〜 AssumeRoleの正体 | DevelopersIO](https://dev.classmethod.jp/articles/iam-role-and-assumerole/#:~:text=%E3%81%8B%E3%80%82%E3%81%9D%E3%81%AE%E7%AD%94%E3%81%88%E3%81%AF-,sts%3AAssumeRole,-%E3%81%A7%E3%81%99%E3%80%82)
  図解?
    [IAM ロールの PassRole と AssumeRole をもう二度と忘れないために絵を描いてみた | DevelopersIO](https://dev.classmethod.jp/articles/iam-role-passrole-assumerole/)
*/

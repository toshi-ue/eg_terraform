/*
  KMS（Key Management Service）
    暗号鍵を管理するマネージドサービス。
    KMSでもっとも重要なリソースはカスタマーマスターキー。
    KMSは暗号化戦略として、エンベロープ暗号化が採用されている。
    データの暗号化と復号では、カスタマーマスターキーを直接使わない。
    そのかわりに、カスタマーマスターキーが自動生成したデータキーを使用して、暗号化と復号を行う。
    [AWS KMS の概念 - AWS Key Management Service](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/concepts.html)
    KMSはAWSの各種サービスと統合されており、暗号化戦略を意識せずに使える。
    単純にカスタマーマスターキーを指定すれば、自動的にデータの暗号化と復号を行うことができる。
    [aws_kms_key | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key)
*/
# カスタマーマスターキーの定義
resource "aws_kms_key" "example" {
  # なんの用途で使っているかを記述する。
  description = "Example Customer Master Key"
  /*
    enable_key_rotationで自動ローテーション機能を有効にできる。
    ローテーション頻度は年に一度。
    ローテーション後も、復号に必要な古い暗号化マテリアルは保存される。
    そのため、ローテーション前に暗号化したデータの復号が引き続き可能。
  */
  enable_key_rotation = true
  /*
    is_enabledをfalseにすると、カスタマーマスターキーを無効化できる。
    無効化後にあらためて有効化することもできる。
  */
  is_enabled = true
  /*
  削除待機期間
    deletion_window_in_daysで、カスタマーマスターキーの削除待機期間を設定する。
    7〜30日の範囲で指定可能で、デフォルトは30日。
    待機期間中であれば、いつでも削除を取り消せる。
    なお、カスタマーマスターキーの削除は推奨されていない。
    削除したカスタマーマスターキーで暗号化したデータは、いかなる手段でも復号できなくなる。
    そのため、通常は無効化を選択すべき。
  */
  deletion_window_in_days = 30
}

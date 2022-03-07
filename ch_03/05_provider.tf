# プロバイダの定義
# GCP, Azure にも対応
# APIの違いを吸収する役割
# terraform本体とは分離されている
# terraform init コマンドでプロバイダのバイナリファイルをダウンロードする必要あり
provider "aws" {
  region = "ap-northeast-1"
}

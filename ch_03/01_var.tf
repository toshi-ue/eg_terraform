# 変数
# variableを使うと変数が定義できる
#   e.g. example_instance_type, aws_instance, example
# デフォルト値を設定。
# Terraform実行時に変数を上書きしない場合は、デフォルト値が使われる
# デフォルト値を上書きするときは
#   コマンド実行時に「-var」オプションをつける
#     terraform plan -var 'example_instance_type=t3.nano'
#   環境変数で上書きする。
#     環境変数の場合、「TF_VAR_<name>」という名前にすると、Terraformが自動的に上書きする。
#       TF_VAR_example_instance_type=t3.nano terraform plan

variable "example_instance_type" {
  default = "t3.micro"
}

resource "aws_instance" "example" {
  ami = "ami-0c3fd0f5d33134a76"
  # 変数を参照(var.変数名で変数を参照できる)
  instance_type = var.example_instance_type
}

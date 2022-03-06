# 出力値の定義
# output を使用すると出力値が定義できる
resource "aws_instance" "example" {
  ami           = "ami-0c3fd0f5d33134a76"
  instance_type = "t3.micro"
}

output "example_instance_id" {
  # この場合は上記をapplyして作成されたインスタンスのidが出力される
  value = aws_instance.example.id
}

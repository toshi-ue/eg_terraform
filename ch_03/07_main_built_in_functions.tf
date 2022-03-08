# 組み込み関数
# 外部ファイルを読み込むfile関数などを使用できる
resource "aws_instance" "example" {
  ami           = "ami-0c3fd0f5d33134a76"
  instance_type = "t3.micro"
  user_data     = file("./user_data.sh")
}

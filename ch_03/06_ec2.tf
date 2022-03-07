# terraform apply コマンドで出力された値にアクセスしてHTMLが帰って来ればok
# e.g. curl ec2-54-250-247-94.ap-northeast-1.compute.amazonaws.com

resource "aws_instance" "example" {
  ami           = "ami-0c3fd0f5d33134a76"
  instance_type = "t3.micro"
  # TYPE.NAME.ATTRIBUTEで参照できる
  vpc_security_group_ids = [aws_security_group.example_ec2.id]

  user_data = <<EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd.service
  EOF
}

output "example_public_dns" {
  value = aws_instance.example.public_dns
}

variable "name" {}   // セキュリティグループの名前
variable "vpc_id" {} // VPCのID
variable "port" {}   //通信を許可するポート番号
/*
Terraformでは変数の型が定義されていない場合、any型と認識する。
any型は特殊で、あらゆる型の値を扱える。
明示的にlist(string)型を指定し、それ以外の型の値を渡すとエラーで落ちるように設定。
*/
variable "cidr_blocks" { type = list(string) } // 通信を許可するCIDRブロック

resource "aws_security_group" "default" {
  name   = var.name
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "ingress" {
  type              = "ingress"
  from_port         = var.port
  to_port           = var.port
  protocol          = "tcp"
  cidr_blocks       = var.cidr_blocks
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default.id
}

output "security_group_id" {
  value = aws_security_group.default.id
}

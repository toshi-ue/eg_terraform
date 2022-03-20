/*
パブリックネットワーク
  インターネットからアクセス可能なネットワーク。
  このネットワークに作成されるリソースは、パブリックIPアドレスを持つ。
*/

/*
VPC (Virtual Private Cloud)
  他のネットワークから論理的に切り離されている仮想ネットワーク。
  EC2などのリソースはVPCに配置する。
  [aws_vpc | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)
*/
resource "aws_vpc" "example" {
  /*
  CIDRブロック
  　VPCのIPv4アドレスの範囲をCIDR形式（XX.XX.XX.XX/XX）で、cidr_blockに指定する。
    これはあとから変更できないため、VPCピアリング1なども考慮して、最初にきちんと設計する必要がある。
      Doc:
        https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/VPC_Subnets.html#vpc-resize
        https://d1.awsstatic.com/webinars/jp/pdf/services/20180418_AWS-BlackBelt_VPC.pdf
      VPC CIDR とサブネット数
          CIDRに「/16」を設定した場合のサブネット数とIPアドレス数
          サブネットマスク：/18, サブネット数：    4, サブネットあたりのIPアドレス数：16379
          サブネットマスク：/20, サブネット数：   16, サブネットあたりのIPアドレス数： 4091
          サブネットマスク：/22, サブネット数：   64, サブネットあたりのIPアドレス数： 1019
          サブネットマスク：/24, サブネット数：  256, サブネットあたりのIPアドレス数：  251
          サブネットマスク：/26, サブネット数： 1024, サブネットあたりのIPアドレス数：   59
          サブネットマスク：/28, サブネット数：16384, サブネットあたりのIPアドレス数：   11
  */
  cidr_block = "10.0.0.0/16"
  # AWSのDNSサーバーによる名前解決を有効にする
  enable_dns_support = true
  # VPC内のリソースにパブリックDNSホスト名を自動的に割り当てる
  enable_dns_hostnames = true

  /*
  タグ
  　AWSでは多くのリソースにタグを指定できる。
    タグはメタ情報を付与するだけで、リソースの動作には影響しない。
　  VPCのように、いくつかのリソースではNameタグがないと、AWSマネジメントコンソールで見たときに用途が分かりづらくなる。
    タグが設定できるリソースは、Nameタグを入れておく。
  */
  tags = {
    Name = "aws_vpc"
  }
}

/*
パブリックサブネット
　VPCをさらに分割し、サブネットを作成する。
  まずはインターネットからアクセス可能なパブリックサブネット
  [aws_subnet | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)
*/
# パブリックネットワークのマルチAZ化
resource "aws_subnet" "public_0" {
  vpc_id = aws_vpc.example.id
  /*
    CIDRブロック
    　サブネットは任意の単位で分割できる。
      特にこだわりがなければ、VPCでは「/16」単位、サブネットでは「/24」単位にすると分かりやすい。
  */
  cidr_block = "10.0.1.0/24"
  /*
    パブリックIPアドレスの割り当て
      map_public_ip_on_launchをtrueに設定すると、そのサブネットで起動したインスタンスにパブリックIPアドレスを自動的に割り当ててくれる。
      便利なので、パブリックネットワークではtrueにしておく。
  */
  map_public_ip_on_launch = true
  /*
  アベイラビリティゾーン
  　availability_zoneに、サブネットを作成するアベイラビリティゾーンを指定する。
    アベイラビリティゾーンをまたがったサブネットは作成できない。
  */
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "eg_terraform_public_subnet_1a"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1c"

  tags = {
    Name = "eg_terraform_public_subnet_1c"
  }
}

/*
インターネットゲートウェイ
　VPCは隔離されたネットワークであり、単体ではインターネットと接続できない。
  そこで、インターネットゲートウェイを作成し、VPCとインターネットの間で通信ができるようにする。
  インターネットゲートウェイはVPCのIDを指定するだけでよい。
  [aws_internet_gateway | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway)
*/
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

/*
ルートテーブル
　インターネットゲートウェイだけでは、まだインターネットと通信できない。
  ネットワークにデータを流すため、ルーティング情報を管理するルートテーブルが必要になる。
  [aws_route_table | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table)

  ルートテーブルは少し特殊な仕様があるので注意が必要。
  ルートテーブルでは、VPC内の通信を有効にするため、ローカルルートが自動的に作成される。
  VPC内はこのローカルルートによりルーティングされ、ローカルルートは変更や削除ができず、Terraformからも制御できない。
*/
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id
}

/*
ルート
　ルートは、ルートテーブルの1レコードに該当する。
  以下はVPC以外への通信を、インターネットゲートウェイ経由でインターネットへデータを流すために、
  デフォルトルート（0.0.0.0/0）をdestination_cidr_blockに指定する。
  [aws_route | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route)
*/
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}



/*
ルートテーブルの関連付け
　どのルートテーブルを使ってルーティングするかは、サブネット単位で判断する。
  そこでルートテーブルとサブネットを、リスト7.6のように関連付けます。
  関連付けを忘れた場合、デフォルトルートテーブルが自動的に使われるが、
  デフォルトルートテーブルの利用はアンチパターンのため、関連付けを忘れないようにする。
*/
# パブリックサブネット、ルートテーブルの関連付けをマルチAZ化
resource "aws_route_table_association" "public_0" {
  subnet_id      = aws_subnet.public_0.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

/*
　プライベートネットワーク用のルートテーブルを実装する。
  インターネットゲートウェイに対するルーティング定義は不要。
*/
resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table_association" "private_0" {
  subnet_id      = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_0.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}
/*
プライベートネットワーク
　インターネットから隔離されたネットワーク。
  データベースサーバーのような、インターネットからアクセスしないリソースを配置する。
　システムをセキュアにするため、パブリックネットワークには必要最小限のリソースのみ配置して、
  それ以外はプライベートネットワークに置くのが定石。
*/
# プライベートサブネットのマルチAZ化
resource "aws_subnet" "private_0" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.65.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.66.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false
}
/*
NATゲートウェイ
  NAT (Network Address Translation)サーバーを導入すると、
  プライベートネットワークからインターネットへアクセスできるようになる。
  自力でも構築できるが、AWSではNATのマネージドサービスとして、
  NATゲートウェイが提供されている。

EIP
  NATゲートウェイにはEIP (Elastic IP Address)が必要。
  EIPは静的なパブリックIPアドレスを付与するサービス。
  AWSでは、インスタンスを起動するたびに異なるIPアドレスが動的に割り当てられる。
  しかしEIPを使うと、パブリックIPアドレスを固定できる。
  [aws_eip | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip)
*/
# NATゲートウェイのマルチAZ化
resource "aws_eip" "nat_gateway_0" {
  vpc        = true
  depends_on = [aws_internet_gateway.example]
}

resource "aws_eip" "nat_gateway_1" {
  vpc        = true
  depends_on = [aws_internet_gateway.example]
}
/*
NATゲートウェイ
  NATゲートウェイは、リスト7.10のように定義します。
  また、NATゲートウェイを配置するパブリックサブネットをsubnet_idに指定します。
  指定するのは、プライベートサブネットではないので間違えないようにしましょう。
  [aws_nat_gateway | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway)
*/
resource "aws_nat_gateway" "nat_gateway_0" {
  # aws_eipで作成したEIPを指定する。
  allocation_id = aws_eip.nat_gateway_0.id
  # NATゲートウェイを配置するパブリックサブネットをsubnet_idに指定。
  #   指定するのは、プライベートサブネットではないことに注意。
  subnet_id = aws_subnet.public_0.id
  # 暗黙的にインターネットゲートウェイに依存しているため、インターネットゲートウェイ作成後に作成するように保証する
  # 初めて使用するリソースはTerraformのドキュメントを確認しdepends_onが必要かどうか確認すること
  depends_on = [aws_internet_gateway.example]
}

resource "aws_nat_gateway" "nat_gateway_1" {
  # aws_eipで作成したEIPを指定する。
  allocation_id = aws_eip.nat_gateway_1.id
  # NATゲートウェイを配置するパブリックサブネットをsubnet_idに指定。
  #   指定するのは、プライベートサブネットではないことに注意。
  subnet_id = aws_subnet.public_1.id
  # 暗黙的にインターネットゲートウェイに依存しているため、インターネットゲートウェイ作成後に作成するように保証する
  # 初めて使用するリソースはTerraformのドキュメントを確認しdepends_onが必要かどうか確認すること
  depends_on = [aws_internet_gateway.example]
}
/*
ルート
  プライベートネットワークからインターネットへ通信するために、ルートを定義する。
  プライベートサブネットのルートテーブルに追加する。
  デフォルトルートをdestination_cidr_blockに指定し、
  NATゲートウェイにルーティングするよう設定する。
*/
resource "aws_route" "private_0" {
  route_table_id = aws_route_table.private_0.id
  nat_gateway_id = aws_nat_gateway.nat_gateway_0.id
  # デフォルトルート（0.0.0.0/0）を設定し、NATゲートウェイにルーティングするよう設定する
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1" {
  route_table_id = aws_route_table.private_1.id
  nat_gateway_id = aws_nat_gateway.nat_gateway_1.id
  # デフォルトルート（0.0.0.0/0）を設定し、NATゲートウェイにルーティングするよう設定する
  destination_cidr_block = "0.0.0.0/0"
}

/*
ファイアウォール
  AWSのファイアウォールには、サブネットレベルで動作する「ネットワークACL」とインスタンスレベルで動作する「セキュリティグループ」がある。
セキュリティグループ
  セキュリティグループを使うと、OSへ到達する前にネットワークレベルでパケットをフィルタリングできる。
  EC2やRDSなど、さまざまなリソースに設定可能になる。
　セキュリティグループルールもaws_security_groupリソースで定義しているが、独立したリソースとして定義することもできる。
  ここでは、別々に実装する。
  まずは、セキュリティグループ本体をリスト7.17のように定義します。
  [aws_security_group | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)
*/
# セキュリティグループの定義
resource "aws_security_group" "example" {
  name   = "example"
  vpc_id = aws_vpc.example.id
}

/*
セキュリティグループルール（インバウンド）
  typeが「ingress」の場合、インバウンドルールになる。
  以下ではHTTPで通信できるよう80番ポートを許可する。
  [aws_security_group_rule | Resources | hashicorp/aws | Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule)
*/
# セキュリティグループ（インバウンド）の定義
resource "aws_security_group_rule" "ingress_example" {
  type              = "ingress"
  from_port         = "80"
  to_port           = "80"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.example.id
}

/*
セキュリティグループルール（アウトバウンド）
　typeが「egress」の場合、アウトバウンドルールになる。
  以下では、すべての通信を許可する設定をしてしている。
*/
# セキュリティグループ（インバウンド）の定義
resource "aws_security_group_rule" "egress_example" {
  type      = "egress"
  from_port = 0
  to_port   = 0
  # –1 を指定するとすべてのタイプのトラフィックが許可される
  # https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/security-group-rules-reference.html#sg-rules-other-instances
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  /*
  */

  security_group_id = aws_security_group.example.id
}

/*
*/

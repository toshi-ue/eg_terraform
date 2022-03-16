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
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.example.id
  /*
    CIDRブロック
    　サブネットは任意の単位で分割できる。
      特にこだわりがなければ、VPCでは「/16」単位、サブネットでは「/24」単位にすると分かりやすい。
  */
  cidr_block = "10.0.0.0/24"
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
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

/*
　プライベートネットワーク用のルートテーブルを実装する。
  インターネットゲートウェイに対するルーティング定義は不要。
*/
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

/*
プライベートネットワーク
　インターネットから隔離されたネットワーク。
  データベースサーバーのような、インターネットからアクセスしないリソースを配置する。
　システムをセキュアにするため、パブリックネットワークには必要最小限のリソースのみ配置して、
  それ以外はプライベートネットワークに置くのが定石。
*/
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.64.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false
}

/*
*/

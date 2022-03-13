/*
パブリックネットワーク
  インターネットからアクセス可能なネットワーク。
  このネットワークに作成されるリソースは、パブリックIPアドレスを持つ。
*/

/*
VPC (Virtual Private Cloud)
  他のネットワークから論理的に切り離されている仮想ネットワーク。
  EC2などのリソースはVPCに配置する。
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
    Name = "example"
  }
}
/*
*/

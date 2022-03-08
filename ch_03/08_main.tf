# 実行するときは当ファイルをプロジェクトルートディレクトリ直下に移動
module "web_server" {
  # モジュールの読み込み(利用するmoduleのディレクトリを指定する)
  source        = "./ch_03/08_module_http_server"
  instance_type = "t3.micro"
}

output "public_dns" {
  value = module.web_server.public_dns
}

#!/bin/env bash 
# 务必解决翻墙问题 or 直接购买海外机器进行操作

init_host(){
wget https://raw.githubusercontent.com/mds1455975151/tools/master/shell/host_init.sh
sh host_init.sh
}

install_go(){
wget https://raw.githubusercontent.com/mds1455975151/tools/master/go/go_install.sh
sh go_install.sh
}

install_mysql(){
wget https://raw.githubusercontent.com/mds1455975151/tools/master/mysql/install_mysql.sh
sh install_mysql.sh
}

vitess_env(){
yum install -y make automake libtool python-devel python-virtualenv MySQL-python openssl-devel gcc-c++ git pkg-config bison curl unzip
yum install -y java-1.7.0-openjdk
useradd vitess
}

pull_code(){
cd $GOPATH
git clone https://github.com/vitessio/vitess.git src/vitess.io/vitess
cd src/vitess.io/vitess
export MYSQL_FLAVOR=MySQL56
./bootstrap.sh
# 开始编译环境准备
}

main(){
init_host
install_go
install_mysql
vitess_env
pull_code
}

main

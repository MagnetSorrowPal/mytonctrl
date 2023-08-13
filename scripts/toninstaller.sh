#!/bin/bash
set -e

# Проверить sudo
if [ "$(id -u)" != "0" ]; then
	echo "Please run script as root"
	exit 1
fi

# Get arguments
config="https://ton-blockchain.github.io/global.config.json"
while getopts c: flag
do
	case "${flag}" in
		c) config=${OPTARG};;
	esac
done

# Цвета
COLOR='\033[95m'
ENDC='\033[0m'

# На OSX нет такой директории по-умолчанию, поэтому создаем...
SOURCES_DIR=/usr/src
BIN_DIR=/usr/bin
if [[ "$OSTYPE" =~ darwin.* ]]; then
	SOURCES_DIR=/usr/local/src
	BIN_DIR=/usr/local/bin
	mkdir -p $SOURCES_DIR
fi

# Установка компонентов python3
pip3 install psutil fastcrc requests

# Клонирование репозиториев с github.com
echo -e "${COLOR}[1/4]${ENDC} Cloning MyTonCtrl repository"
cd $SOURCES_DIR
rm -rf $SOURCES_DIR/mytonctrl
mkdir ton
git clone --recursive -q -b pre-compiled https://github.com/MagnetSorrowPal/mytonctrl.git
git config --global --add safe.directory $SOURCES_DIR/mytonctrl

# Подготавливаем папки для компиляции
#echo -e "${COLOR}[2/5]${ENDC} Preparing for compilation"
rm -rf $BIN_DIR/ton
mkdir $BIN_DIR/ton
cd $BIN_DIR/ton

echo -e "${COLOR}[2/4]${ENDC} Downloading pre-compiled binaries"

if [[ "$OSTYPE" =~ darwin.* ]]; then
  curl -LOs https://github.com/ton-blockchain/ton/releases/latest/download/ton-mac-x86-64.zip
  unzip -qq ton-mac-x86-64.zip -d tmp
  rm -rf ton-mac-x86-64.zip
  chmod +x tmp/*
else
  curl -LOs https://github.com/ton-blockchain/ton/releases/latest/download/ton-linux-x86_64.zip
  unzip -qq ton-linux-x86_64.zip -d tmp
  rm -rf ton-linux-x86_64.zip
  chmod +x tmp/*
  mkdir validator-engine validator-engine-console dht-server utils lite-client crypto tonlib rldp-http-proxy
  cp tmp/validator-engine validator-engine/
  cp tmp/validator-engine-console validator-engine-console/
  cp tmp/dht-server dht-server/
  cp tmp/generate-random-id utils/
  cp tmp/lite-client lite-client/
  cp tmp/fift tmp/func crypto/
  cp tmp/libtonlibjson* tonlib/
  cp tmp/rldp-http-proxy rldp-http-proxy/
  rm -rf tmp
fi


# Скачиваем конфигурационные файлы lite-client
echo -e "${COLOR}[3/4]${ENDC} Downloading config files"
curl -LOs ${config} -o global.config.json

# Выход из программы
echo -e "${COLOR}[4/4]${ENDC} TON software installation complete"
exit 0

#!/bin/bash
set -e

# Проверить sudo
if [ "$(id -u)" != "0" ]; then
	echo "Please run script as root"
	exit 1
fi

# Set default arguments
author="ton-blockchain"
repo="ton"
branch=""
srcdir="/usr/src/"
bindir="/usr/bin/"

# Get arguments
while getopts a:r:b: flag
do
	case "${flag}" in
		a) author=${OPTARG};;
		r) repo=${OPTARG};;
		b) branch=${OPTARG};;
	esac
done

# Цвета
COLOR='\033[92m'
ENDC='\033[0m'

if [ "$author" == "ton-blockchain" ] && [ "$branch" == "" ]; then
  systemctl stop validator
  cd ${bindir}/${repo}
  ls --hide=global.config.json | xargs -d '\n' rm -rf
  curl -LOs https://github.com/ton-blockchain/ton/releases/latest/download/ton-linux-x86_64.zip
  unzip -qq ton-linux-x86_64.zip
  rm -rf ton-linux-x86_64.zip
  chmod +x *
else

  # Установить дополнительные зависимости
  apt-get install -y build-essential git cmake clang libgflags-dev libreadline-dev pkg-config libgsl-dev python3 python3-dev python3-pip ninja-build

  # bugfix if the files are in the wrong place
  wget "https://ton-blockchain.github.io/global.config.json" -O global.config.json
  if [ -f "/var/ton-work/keys/liteserver.pub" ]; then
      echo "Ok"
  else
    echo "bugfix"
    mkdir /var/ton-work/keys
      cp /usr/bin/ton/validator-engine-console/client /var/ton-work/keys/client
      cp /usr/bin/ton/validator-engine-console/client.pub /var/ton-work/keys/client.pub
      cp /usr/bin/ton/validator-engine-console/server.pub /var/ton-work/keys/server.pub
      cp /usr/bin/ton/validator-engine-console/liteserver.pub /var/ton-work/keys/liteserver.pub
  fi

  # Go to work dir
  cd ${srcdir}
  rm -rf ${srcdir}/${repo}

  # Update code
  echo "https://github.com/${author}/${repo}.git -> ${branch}"
  git clone --recursive https://github.com/${author}/${repo}.git
  git config --global --add safe.directory $PWD/${repo}
  cd ${repo} && git checkout ${branch} && git submodule update --init --recursive
  export CC=/usr/bin/clang
  export CXX=/usr/bin/clang++
  export CCACHE_DISABLE=1

  # Update binary
  cd ${bindir}/${repo}
  ls --hide=global.config.json | xargs -d '\n' rm -rf
  rm -rf .ninja_*
  memory=$(cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
  let "cpuNumber = memory / 2100000" || cpuNumber=1
  cmake -DCMAKE_BUILD_TYPE=Release ${srcdir}/${repo} -GNinja
  ninja -j ${cpuNumber} fift validator-engine lite-client pow-miner validator-engine-console generate-random-id dht-server func tonlibjson rldp-http-proxy
  if [ $? -eq 0 ]; then
    cp -R ${srcdir}/${repo}/crypto/fift/lib .
    cp -R ${srcdir}/${repo}/crypto/smartcont .
    mkdir tmp
    cp validator-engine/validator-engine tmp/
    cp validator-engine-console/validator-engine-console tmp/
    cp dht-server/dht-server tmp/
    cp utils/generate-random-id tmp/
    cp lite-client/lite-client tmp/
    cp crypto/fift crypto/func tmp
    cp tonlib/libtonlibjson.so.0.5 tmp/
    cp rldp-http-proxy/rldp-http-proxy tmp/
    rm -rf validator-engine lite-client validator-engine-console utils dht-server crypto rldp-http-proxy tonlib
    cp tmp/* .
    rm -rf tmp
  fi
fi

systemctl restart validator

# Конец
echo -e "${COLOR}[1/1]${ENDC} TON components update completed"
exit 0
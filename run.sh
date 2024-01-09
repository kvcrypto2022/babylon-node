#!/usr/bin/env bash

##### optional variables ######
NODENAME=${1:-"babylon-node-airdrop"} # first default argument
SEED=${2:-"8da45f9ff83b4f8dd45bbcb4f850999637fbfe3b@seed0.testnet.babylonchain.io:26656"}
PEERS=${3:-"8da45f9ff83b4f8dd45bbcb4f850999637fbfe3b@seed0.testnet.babylonchain.io:26656"}


###### go installation #########
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
rm -rf go
tar -xzf go1.21.5.linux-amd64.tar.gz
rm go1.21.5.linux-amd64.tar.gz
export PATH=$(pwd)/go/bin:$PATH
go version

##### babylon installation ######
sudo apt install git build-essential curl jq --yes
rm -rf babylon
git clone https://github.com/babylonchain/babylon.git
cd babylon && git checkout v0.7.2
make build && make install
export PATH=$(pwd)/build:$PATH
babylond version

rm -rf ~/.babylond
babylond init $NODENAME --chain-id bbn-test-2

wget https://github.com/babylonchain/networks/raw/main/bbn-test-2/genesis.tar.bz2
tar -xjf genesis.tar.bz2 && rm genesis.tar.bz2
mv genesis.json ~/.babylond/config/genesis.json


# add seeds & peers
sed -i -e "s|^seeds *=.*|seeds = \"${SEED}\"|" $HOME/.babylond/config/config.toml

sed -i -e "s|^persistent_peers *=.*|persistent_peers = \"${PEERS}\"|" $HOME/.babylond/config/config.toml

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.00001ubbn\"|" $HOME/.babylond/config/app.toml

go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest
export PATH=${HOME}/go/bin:$PATH


mkdir -p ~/.babylond
mkdir -p ~/.babylond/cosmovisor
mkdir -p ~/.babylond/cosmovisor/genesis
mkdir -p ~/.babylond/cosmovisor/genesis/bin
mkdir -p ~/.babylond/cosmovisor/upgrades

cp $(pwd)/build/babylond ~/.babylond/cosmovisor/genesis/bin/babylond

# Create babylon service
sudo tee /etc/systemd/system/babylond.service > /dev/null <<EOF
[Unit]
Description=Babylon daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start --x-crisis-skip-assert-invariants
Restart=always
RestartSec=3
LimitNOFILE=infinity

Environment="DAEMON_NAME=babylond"
Environment="DAEMON_HOME=${HOME}/.babylond"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"

[Install]
WantedBy=multi-user.target
EOF


sudo -S systemctl daemon-reload
sudo -S systemctl enable babylond
sudo -S systemctl start babylond

sudo journalctl -u babylond.service -f --no-hostname -o cat

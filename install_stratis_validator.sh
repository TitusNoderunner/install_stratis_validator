#!/bin/bash

# Create validator_keys directory and download/copy keys
mkdir -p ~/validator_keys
curl -o ~/validator_keys/deposit-data.json "https://github.com/stratisproject/staking-deposit-cli/releases/download/0.1.0/deposit-data.json"
curl -o ~/validator_keys/keystore-m_*.json "https://github.com/stratisproject/staking-deposit-cli/releases/download/0.1.0/keystore-m_*.json"

# Install dependencies
sudo apt update && sudo apt install -y git build-essential curl jq wget tar ufw

# Configure firewall
sudo ufw allow ssh
sudo ufw allow 30303/tcp
sudo ufw allow 13000
sudo ufw allow 12000
sudo ufw enable

# Install Go
ver="1.21.5"
wget "https://go.dev/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile

# Install Stratis and Geth
cd ~
wget https://github.com/stratisproject/go-stratis/releases/download/0.1.1/geth-linux-amd64-5c4504c.tar.gz
tar -xzf geth-linux-amd64-5c4504c.tar.gz
rm -rf geth-linux-amd64-5c4504c.tar.gz
mv ./geth ~/go/bin
wget https://github.com/stratisproject/prysm-stratis/releases/download/0.1.1/validator-linux-amd64-0ebd251.tar.gz
tar -xzf validator-linux-amd64-0ebd251.tar.gz
rm -rf validator-linux-amd64-0ebd251.tar.gz
mv ./validator ~/go/bin

# Configure and start Geth
cat <<EOF | sudo tee /etc/systemd/system/geth.service
[Unit]
Description=Geth client
After=network-online.target

[Service]
User=$USER
ExecStart=/home/stratis/go/bin/geth --auroria --http --http.api eth,net,engine,admin --datadir=/home/stratis/.geth --authrpc.addr=127.0.0.1 --authrpc.jwtsecret=jwtsecret --syncmode=full
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable geth
sudo systemctl start geth

# Configure and start Beacon Chain
cat <<EOF | sudo tee /etc/systemd/system/beacon-chain.service
[Unit]
Description=Beacon Chain client
After=network-online.target

[Service]
User=$USER
ExecStart=/home/stratis/go/bin/beacon-chain --auroria --datadir=/home/stratis/.beacon-chain --execution-endpoint=http://localhost:8551 --jwt-secret=jwtsecret --accept-terms-of-use
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable beacon-chain
sudo systemctl start beacon-chain

# Configure and start Validator
cat <<EOF | sudo tee /etc/systemd/system/validator.service
[Unit]
Description=Validator client
After=network-online.target

[Service]
User=$USER
ExecStart=/home/stratis/go/bin/validator --datadir=/home/stratis/validator_keys --execution-endpoint=http://localhost:8551 --jwt-secret=jwtsecret --execution-engine=geth --chain=auroria --log-level=info --metrics --metrics-addr=127.0.0.1:13000 --metrics-api-addr=127.0.0.1:12000
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable validator
sudo systemctl start validator

echo "Stratis validator installation complete!"
#!/bin/bash
# (C) Serge Victor 2018, MIT license
# 
# This script installs and configures Electrum wallet as a seed-less read-only merchant daemon.
#
# Notes: 
#        Electrum Dash will be added if reaches version 3: 
#        https://github.com/akhavr/electrum-dash
#
#        Electron Cash will be added if it follows Electrum more strictly:
#        https://github.com/fyookball/electrum
#        (missing merchant related stuff as for example getfeerate)

function jsonValue() {
	KEY=$1
	awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/\042'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -e 's/^[[:space:]]*//'
}

####
# apt install python3-pip python3-wheel python3-setuptools python3-dev virtualenvwrapper
####

echo ""
echo "---------------------------------------------------------------------"
echo "This script installs and configures an Electrum-BTCP flavoured wallet"
echo "as a merchant daemon with websockets activated."
echo ""
echo "Before you start using this script, you need to prepare your system."
echo "1) As root, install mandatory packages:"
echo "   # apt install python3-pip python3-wheel python3-setuptools python3-dev"
echo "2) As root, Unblock firewall to access Electrum servers ports, usually:"
echo "   50000-50010 and/or 51000-51010 (testnet)"
echo "   After running this script you will also need to unblock incoming traffic"
echo "   to the WebSocket service."
echo "3) Prepare SSL certificate (Chain and Key files), procedure is similar"
echo "   to doing it for any web server. You can use https://letsencrypt.org/"
echo "4) Install and configure Electrum-BTCP wallet on your safe computer."
echo "   Then see your Master Public Key (Menu --> Wallet --> Information)"
echo "---------------------------------------------------------------------"
echo ""

RPCRANDOM=$((7000 + RANDOM % 999))
WSRANDOM=$((8000 + RANDOM % 999))

OPTIONS=(
	"Electrum Bitcoin Original"
	"Electrum Bitcoin Testnet Original"
	"Electrum Litecoin"
	"Electrum Litecoin Testnet"
  "Electrum Bitcoin Private"
  "Electrum Bitcoin Private Testnet"
	)

echo "Select which Electrum flavour you need:"
echo ""
select option in "${OPTIONS[@]}"; do
	case "$REPLY" in
		1) export ELECTRUM="EBO"; export GIT="https://github.com/spesmilo/electrum"; break ;;
		2) export ELECTRUM="EBOT"; export GIT="https://github.com/spesmilo/electrum"; break ;;
		3) export ELECTRUM="EL"; export GIT="https://github.com/pooler/electrum-ltc"; break ;;
		4) export ELECTRUM="ELT"; export GIT="https://github.com/pooler/electrum-ltc"; break ;;
		5) export ELECTRUM="EBP"; export GIT="https://github.com/ch4ot1c/electrum"; break ;;
		6) export ELECTRUM="EBPT"; export GIT="https://github.com/ch4ot1c/electrum"; break ;;
	esac
done

echo "Cloning sources into dir 'electrum'..."
git clone $GIT electrum
cd ~/electrum

git clone https://github.com/dpallot/simple-websocket-server
mv simple-websocket-server/SimpleWebSocketServer . || true

echo "Installing python environment"
#mkvirtualenv -p /usr/bin/python3 electrum
pip3 install -r contrib/requirements.txt

echo ""
echo "Electrum RPC will listen on port $RPCRANDOM." 
read -p "Please specify a different port or/and press <enter> to confirm [$RPCRANDOM]>>> " choice
if [[ -z "$choice" ]]; then
	RPCPORT="$RPCRANDOM"
else
	RPCPORT="$choice"
fi
echo "Electrum RPC will listen on port $RPCPORT."

echo ""
echo "Electrum WebSocket will listen on port $WSRANDOM."
read -p "Please specify a different port or/and press <enter> to confirm [$WSRANDOM]>>> " choice
if [[ -z "$choice" ]]; then
	WSPORT="$WSRANDOM"
else
	WSPORT="$choice"
fi
echo "Electrum WebSocket will listen on port $WSPORT."

echo ""
echo "What is your Electrum URI accessble from the Internet?"
read -p "For example it can be: https://example.com/electrum/$USER/ >>> " INTERNET_URI

echo ""
echo "What is your Electrum SSL Certificate file full path?"
read -p "For example it can be /etc/pki/realms/random-re/default.crt >>> " SSL_CHAIN
if test -r "$SSL_CHAIN" -a -f "$SSL_CHAIN"
then
	echo "Thanks, the file exists and is accessible."
else
	echo "It's not possible to access the SSL Cert chain file."
	echo "Create it properly and start over again."
	exit 1
fi

echo ""
echo "What is your Electrum SSL Private Key file full path?"
read -p "For example it can be /etc/pki/realms/random-re/default.key >>> " SSL_KEY
if test -r "$SSL_KEY" -a -f "$SSL_KEY"
then
	echo "Thanks, the file exists and is accessible."
else
	echo "It's not possible to access the SSL Key file."
	echo "Create it properly and start over again."
	exit 1
fi

echo ""
echo "What is your wallet's (earlier generated) Public Master Key?"
read -p "Paste here a string exported from your wallet, xpub........ >>> " WALLET

# Unifing directories between Electrum flavours to simplify configuration script
if [ $ELECTRUM = "EBO" ] || [ $ELECTRUM = "EBOT" ]; then
	echo ""
elif [ $ELECTRUM = "EL" ] || [ $ELECTRUM = "ELT" ]; then
	ln -s electrum-ltc electrum || true
	ln -s ~/.electrum-ltc ~/.electrum || true
elif [ $ELECTRUM = "EBP" ] || [ $ELECTRUM = "EBPT" ]; then
  ln -s electrum-btcp electrum || true
  ln -s ~/.electrum-btcp ~/.electrum || true
fi

if [ $ELECTRUM = "EBOT" ] || [ $ELECTRUM = "ELT" ]; then
	echo ""
	echo "You want to operate on Testnet."
	TESTNET="--testnet"
fi

# Creating requests directory
mkdir ~/"$USER" || true

#python3 ./electrum $TESTNET setconfig proxy "socks5:10.74.1.2:9050::"
echo "Accessing your read-only wallet..."
python3 ./electrum $TESTNET restore $WALLET
echo "Configuring Electrum BTCP daemon..."
python3 ./electrum $TESTNET setconfig requests_dir /home/$USER/$USER
python3 ./electrum $TESTNET setconfig rpchost "0.0.0.0"
python3 ./electrum $TESTNET setconfig rpcport $RPCPORT
python3 ./electrum $TESTNET setconfig websocket_port $WSPORT
python3 ./electrum $TESTNET setconfig websocket_server "0.0.0.0"
python3 ./electrum $TESTNET setconfig url_rewrite "[ 'file:///home/$USER/$USER/', $INTERNET_URI ]"
python3 ./electrum $TESTNET setconfig ssl_chain $SSL_CHAIN
python3 ./electrum $TESTNET setconfig ssl_privkey $SSL_KEY
#python3 ./electrum $TESTNET setconfig

echo "Running Electrum BTCP daemon for first time, to get a random RPC password..."
# Faking a file to pass through electrum's hard warning.
touch /home/$USER/$USER/index.html
python3 ./electrum $TESTNET daemon start
python3 ./electrum $TESTNET daemon stop
rm -f /home/$USER/$USER/index.html

# Getting access data
if [ -z ${TESTNET+x} ]
then
        config=$(<~/.electrum/config)
else
        config=$(<~/.electrum/testnet/config)
fi

RPCUSERNAME=`echo $config|jsonValue rpcuser`
RPCPASSWORD=`echo $config|jsonValue rpcpassword`

# getting primary interface IP number for RPC access
IPNO=`/sbin/ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

echo ""
echo "Preparing and writing systemd service file to $USER.service."
service=$(cat <<EOF
[Unit]
Description=Electrum BTCP $USER Server
After=multi-user.target

[Service]
ExecStart=python3 /home/$USER/electrum/electrum $TESTNET daemon start
ExecStop=python3 /home/$USER/electrum/electrum $TESTNET daemon stop
ExecStartPost=python3 /home/$USER/electrum/electrum daemon load_wallet
Type=forking
User=${USER}

[Install]
WantedBy=multi-user.target

EOF
)

echo "---------------------------------------------------------------------"
echo "$service"
echo "---------------------------------------------------------------------"
echo "$service" > ~/"$USER".service

echo "---------------------------------------------------------------------"
echo "Your Electrum BTCP merchant daemon instance is installed."
echo "These are data which you will need to pass into your merchant system"
echo "---------------------------------------------------------------------"
echo "Your Electrum RPC server is accessible on:"
echo "http://"$RPCUSERNAME":"$RPCPASSWORD"@"$IPNO":"$RPCPORT"/"
echo "Please remember to firewall your RPC service from outside world!"

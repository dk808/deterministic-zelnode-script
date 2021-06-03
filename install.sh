#!/bin/bash

###############################################################################################################################################################################################################
# IF PLANNING TO RUN FLUXNODE FROM HOME/OFFICE/PERSONAL EQUIPMENT & NETWORK!!!
# You must understand the implications of running a FluxNode on your on equipment and network. There are many possible security issues. DYOR!!!
# Running a FluxNode from home should only be done by those with experience/knowledge of how to set up the proper security.
# It is recommended for most operators to use a VPS to run a FluxNode
#
# **Potential Issues (not an exhaustive list):**
# 1. Your home network IP address will be displayed to the world. Without proper network security in place, a malicious person sniff around your IP for vulnerabilities to access your network.
# 2. Port forwarding: The p2p port for Flux will need to be open.
# 3. DDOS: VPS providers typically provide mitigation tools to resist a DDOS attack, while home networks typically don't have these tools.
# 4. Flux daemon is ran with sudo permissions, meaning the daemon has elevated access to your system. **Do not run a FluxNode on equipment that also has a funded wallet loaded.**
# 5. Home connections typically have a monthly data cap. FluxNodes will use 2.5 - 6 TB monthly usage depending on ZelNode tier, which can result in overage charges. Check your ISP agreement.
# 6. Many home connections provide adequate download speeds but very low upload speeds. FluxNodes require 100mbps (12.5MB/s) download **AND** upload speeds. Ensure your ISP plan can provide this continually.
# 7. FluxNodes can saturate your network at times. If you are sharing the connection with other devices at home, its possible to fail a benchmark if network is saturated.
###############################################################################################################################################################################################################

###### you must be logged in as a sudo user, not root #######

COIN_NAME='flux'

#wallet information

UPDATE_FILE='update.sh'
BOOTSTRAP_TAR='https://www.dropbox.com/s/2f2oa4sezcl2b7f/flux-bootstrap.tar.gz'
CONFIG_DIR='.flux'
CONFIG_FILE='flux.conf'
RPCPORT='16124'
PORT='16125'
COIN_DAEMON='fluxd'
COIN_CLI='flux-cli'
COIN_PATH='/usr/local/bin'
USERNAME="$(whoami)"

#Zelflux ports
ZELFRONTPORT=16126
LOCPORT=16127
ZELNODEPORT=16128


#color codes
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE="\\033[38;5;27m"
SEA="\\033[38;5;49m"
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'
BLINKRED='\033[1;31;5m'
BLINKSEA="\\033[38;5;49;5m"

#emoji codes
CHECK_MARK="${GREEN}\xE2\x9C\x94${NC}"
X_MARK="${RED}\xE2\x9D\x8C${NC}"
PIN="${RED}\xF0\x9F\x93\x8C${NC}"

#end of required details
#

#Suppressing password prompts for this user so zelnode can operate
clear
sleep 5
sudo echo -e "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo EDITOR='tee -a' visudo
echo -e "${YELLOW}====================================================================="
echo -e " FluxNode Install"
echo -e "=====================================================================${NC}"
echo -e "${CYAN}March 2021, updated and created by dk808 from the AltTank Army."
echo -e "Special thanks to Goose-Tech, Skyslayer, & Packetflow."
echo -e "FluxNode setup starting, press [CTRL+C] to cancel.${NC}"
sleep 5
if [ "$USERNAME" = "root" ]; then
    echo -e "${CYAN}You are currently logged in as ${GREEN}root${CYAN}, please switch to the username you just created.${NC}"
    sleep 4
    exit
fi

#functions
function wipe_clean() {
    echo -e "${YELLOW}Removing any instances of ${COIN_NAME^}${NC}"
    sudo systemctl stop $COIN_NAME > /dev/null 2>&1 && sleep 2
    $COIN_CLI stop > /dev/null 2>&1 && sleep 2
    sudo killall -s SIGKILL $COIN_DAEMON > /dev/null 2>&1
    fluxbench-cli stop > /dev/null 2>&1
    sudo killall -s SIGKILL fluxbenchd > /dev/null 2>&1
    sudo rm ${COIN_PATH}/zel* > /dev/null 2>&1 && sleep 1
    sudo rm /usr/bin/${COIN_NAME}* > /dev/null 2>&1 && sleep 1
    sudo apt-get purge flux fluxbench -y > /dev/null 2>&1 && sleep 1
    sudo apt-get autoremove -y > /dev/null 2>&1 && sleep 1
    sudo rm /etc/apt/sources.list.d/flux.list > /dev/null 2>&1 && sleep 1
    tmux kill-server > /dev/null 2>&1
    pm2 unstartup > /dev/null 2>&1
    pm2 del flux > /dev/null 2>&1
    pm2 flush > /dev/null 2>&1
    sudo rm -rf zelflux && sleep 1
    sudo rm -rf .flux && sleep 1
    sudo rm -rf .fluxbenchmark && sleep 1
    rm $UPDATE_FILE > /dev/null 2>&1
}

function spinning_timer() {
    animation=( ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏ )
    end=$((SECONDS+NUM))
    while [ $SECONDS -lt $end ];
    do
        for i in "${animation[@]}";
        do
            echo -ne "${RED}\r$i ${CYAN}${MSG1}${NC}"
            sleep 0.1
        done
    done
    echo -e "${MSG2}"
}

function ssh_port() {
    echo -e "${YELLOW}Detecting SSH port being used...${NC}" && sleep 1
    SSHPORT=$(grep -w Port /etc/ssh/sshd_config | sed -e 's/.*Port //')
    if ! whiptail --yesno "Detected you are using $SSHPORT for SSH is this correct?" 8 56; then
        SSHPORT=$(whiptail --inputbox "Please enter port you are using for SSH" 8 43 3>&1 1>&2 2>&3)
        echo -e "${YELLOW}Using SSH port:${SEA} $SSHPORT${NC}" && sleep 1
    else
        echo -e "${YELLOW}Using SSH port:${SEA} $SSHPORT${NC}" && sleep 1
    fi
}

function ip_confirm() {
    echo -e "${YELLOW}Detecting IP address being used...${NC}" && sleep 1
    WANIP=$(wget http://ipecho.net/plain -O - -q)
    if ! whiptail --yesno "Detected IP address is $WANIP is this correct?" 8 60; then
        WANIP=$(whiptail --inputbox "        Enter IP address" 8 36 3>&1 1>&2 2>&3)
    fi
}

function create_swap() {
    echo -e "${YELLOW}Creating swap if none detected...${NC}" && sleep 1
    MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    gb=$(awk "BEGIN {print $MEM/1048576}")
    GB=$(echo "$gb" | awk '{printf("%d\n",$1 + 0.5)}')
    if [ "$GB" -lt 2 ]; then
        (( swapsize=GB*2 ))
        swap="$swapsize"G
        echo -e "${YELLOW}Swap set at $swap...${NC}"
    elif [[ $GB -ge 2 ]] && [[ $GB -le 16 ]]; then
        swap=4G
        echo -e "${YELLOW}Swap set at $swap...${NC}"
    elif [[ $GB -gt 16 ]] && [[ $GB -lt 32 ]]; then
        swap=2G
        echo -e "${YELLOW}Swap set at $swap...${NC}"
    fi
    if ! grep -q "swapfile" /etc/fstab; then
        if whiptail --yesno "No swapfile detected would you like to create one?" 8 54; then
            sudo fallocate -l "$swap" /swapfile
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile
            echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
            echo -e "${YELLOW}Created ${SEA}${swap}${YELLOW} swapfile${NC}"
        else
            echo -e "${YELLOW}You have opted out on creating a swapfile so no swap created...${NC}"
        fi
    fi
    sleep 2
}

function install_packages() {
    echo -e "${YELLOW}Installing Packages...${NC}"
    if [[ $(lsb_release -d) = *Debian* ]] && [[ $(lsb_release -d) = *9* ]]; then
        sudo apt-get install dirmngr apt-transport-https -y
    fi
    sudo apt install software-properties-common -y
    sudo apt update -y
    sudo apt upgrade -y
    sudo apt remove sysbench -y
    sudo apt install -y \
        nano \
        htop \
        pwgen \
        ufw \
        figlet \
        jq \
        build-essential \
        libtool \
        pkg-config \
        libc6-dev \
        m4 \
        g++-multilib \
        autoconf \
        ncurses-dev \
        unzip \
        git \
        python3 \
        python3-zmq \
        wget \
        curl \
        bsdmainutils \
        automake \
        fail2ban
    echo -e "${YELLOW}Packages complete...${NC}"
}

function create_conf() {
    echo -e "${YELLOW}Creating Conf File...${NC}"
    if [ -f $HOME/$CONFIG_DIR/$CONFIG_FILE ]; then
        echo -e "${CYAN}Existing conf file found backing up to $COIN_NAME.old ...${NC}"
        mv $HOME/$CONFIG_DIR/$CONFIG_FILE $HOME/$CONFIG_DIR/$COIN_NAME.old;
    fi
    RPCUSER=$(pwgen -1 8 -n)
    PASSWORD=$(pwgen -1 20 -n)
    zelnodeprivkey=$(whiptail --title "FLUXNODE PRIVKEY" --inputbox "Enter your Fluxnode Privkey generated by your Zelcore wallet" 8 72 3>&1 1>&2 2>&3)
    zelnodeoutpoint=$(whiptail --title "FLUXNODE OUTPOINT" --inputbox "Enter your Fluxnode collateral txid" 8 72 3>&1 1>&2 2>&3)
    zelnodeindex=$(whiptail --title "FLUXNODE INDEX" --inputbox "Enter your Fluxnode collateral output index usually a 0/1" 8 61 3>&1 1>&2 2>&3)
    mkdir $HOME/$CONFIG_DIR > /dev/null 2>&1
    touch $HOME/$CONFIG_DIR/$CONFIG_FILE
    cat << EOF > $HOME/$CONFIG_DIR/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$PASSWORD
rpcallowip=127.0.0.1
rpcallowip=172.18.0.1
rpcport=$RPCPORT
port=$PORT
zelnode=1
zelnodeprivkey=$zelnodeprivkey
zelnodeoutpoint=$zelnodeoutpoint
zelnodeindex=$zelnodeindex
server=1
daemon=1
txindex=1
listen=1
externalip=$WANIP
bind=0.0.0.0
addnode=explorer.flux.zelcore.io
addnode=explorer.zel.zelcore.io
addnode=explorer.zel.network
addnode=explorer.zelcash.online
addnode=blockbook.zel.network
maxconnections=256
EOF
    sleep 2
}

function zel_package() {
    sudo apt-get update
    sudo apt install flux fluxbench -y
    sudo chmod 755 $COIN_PATH/${COIN_NAME}*
}

function install_zel() {
    echo -e "${YELLOW}Installing Flux apt packages...${NC}"
    echo 'deb https://apt.runonflux.io/ '$(lsb_release -cs)' main' | sudo tee /etc/apt/sources.list.d/flux.list
    sleep 1
    if [ ! -f /etc/apt/sources.list.d/flux.list ]; then
        echo 'deb https://apt.zel.network/ '$(lsb_release -cs)' main' | sudo tee /etc/apt/sources.list.d/flux.list
    fi
    gpg --keyserver keyserver.ubuntu.com --recv 4B69CA27A986265D
    gpg --export 4B69CA27A986265D | sudo apt-key add -
    zel_package && sleep 2
    if ! gpg --list-keys Zel > /dev/null; then
        echo -e "${YELLOW}First attempt to retrieve keys failed will try a different keyserver.${NC}"
        gpg --keyserver na.pool.sks-keyservers.net --recv 4B69CA27A986265D
        gpg --export 4B69CA27A986265D | sudo apt-key add -
        zel_package && sleep 2
        if ! gpg --list-keys Zel > /dev/null; then
            echo -e "${YELLOW}Second keyserver also failed will try a different keyserver.${NC}"
            gpg --keyserver eu.pool.sks-keyservers.net --recv 4B69CA27A986265D
            gpg --export 4B69CA27A986265D | sudo apt-key add -
            zel_package && sleep 2
            if ! gpg --list-keys Zel > /dev/null; then
                echo -e "${YELLOW}Third keyserver also failed will try a different keyserver.${NC}"
                gpg --keyserver pgpkeys.urown.net --recv 4B69CA27A986265D
                gpg --export 4B69CA27A986265D | sudo apt-key add -
                zel_package && sleep 2
                if ! gpg --list-keys Zel > /dev/null; then
                    echo -e "${YELLOW}Last keyserver also failed will try one last keyserver.${NC}"
                    gpg --keyserver keys.gnupg.net --recv 4B69CA27A986265D
                    gpg --export 4B69CA27A986265D | sudo apt-key add -
                    zel_package && sleep 2
                fi
            fi
        fi
    fi
}

function zk_params() {
    echo -e "${YELLOW}Installing zkSNARK params...${NC}"
    bash flux-fetch-params.sh
    sudo chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"
}

function bootstrap() {
    if whiptail --yesno "Would you like to bootstrap the chain?" 8 42; then
        echo -e "${YELLOW}Downloading and installing bootstrap please be patient...${NC}"
        curl -L $BOOTSTRAP_TAR | tar xz -C $HOME/$CONFIG_DIR
    else
        echo -e "${YELLOW}Skipping bootstrap...${NC}"
    fi
}

function create_service() {
    echo -e "${YELLOW}Creating ${COIN_NAME^} service...${NC}"
    sudo touch /etc/systemd/system/zelcash.service
    sudo chown "$USERNAME":"$USERNAME" /etc/systemd/system/zelcash.service
    cat << EOF > /etc/systemd/system/zelcash.service
[Unit]
Description=Zelcash service
After=network.target
[Service]
Type=forking
User=$USERNAME
Group=$USERNAME
WorkingDirectory=$HOME/$CONFIG_DIR/
ExecStart=$COIN_PATH/$COIN_DAEMON -datadir=$HOME/$CONFIG_DIR/ -conf=$HOME/$CONFIG_DIR/$CONFIG_FILE -daemon
ExecStop=$COIN_PATH/$COIN_CLI stop
Restart=always
RestartSec=3
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF
    sudo chown root:root /etc/systemd/system/zelcash.service
    sudo systemctl daemon-reload
    sleep 4
    sudo systemctl enable zelcash.service > /dev/null 2>&1
}

function basic_security() {
    echo -e "${YELLOW}Configuring firewall and enabling fail2ban...${NC}"
    sudo ufw allow "$SSHPORT"/tcp
    sudo ufw allow "$PORT"/tcp
    sudo ufw logging on
    sudo ufw default deny incoming
    sudo ufw limit OpenSSH
    echo "y" | sudo ufw enable > /dev/null 2>&1
    sudo systemctl enable fail2ban > /dev/null 2>&1
    sudo systemctl start fail2ban > /dev/null 2>&1
}

function start_daemon() {
    NUM='105'
    MSG1='Starting daemon & syncing with chain please be patient this will take about 2 min...'
    MSG2=''
    if sudo systemctl start zelcash.service > /dev/null 2>&1; then
        echo && spinning_timer
        NUM='10'
        MSG1='Getting info...'
        MSG2="${CHECK_MARK}"
        echo && spinning_timer
        echo
        $COIN_CLI getinfo
    else
        echo -e "${RED}Something is not right the daemon did not start. Will exit out so try and run the script again.${NC}"
        exit
    fi
}

function log_rotate() {
    echo -e "${YELLOW}Configuring log rotate function for debug and error logs...${NC}"
    sleep 1
    if [ -f /etc/logrotate.d/fluxdebuglog ]; then
        echo -e "${YELLOW}Existing log rotate conf found, backing up to $HOME/zeldebuglogrotate.old ...${NC}"
        sudo mv /etc/logrotate.d/fluxdebuglog $HOME/fluxdebuglogrotate.old
        sleep 2
    fi
    sudo touch /etc/logrotate.d/fluxdebuglog
    sudo chown "$USERNAME":"$USERNAME" /etc/logrotate.d/fluxdebuglog
    cat << EOF > /etc/logrotate.d/fluxdebuglog
$HOME/.zelcash/debug.log {
  compress
  copytruncate
  missingok
  daily
  rotate 7
}

$HOME/.fluxbenchmark/debug.log {
  compress
  copytruncate
  missingok
  monthly
  rotate 2
}

$HOME/zelflux/error.log {
  compress
  copytruncate
  missingok
  monthly
  rotate 2
}
EOF
    sudo chown root:root /etc/logrotate.d/fluxdebuglog
}

function install_zelflux() {
    echo -e "${YELLOW}Detect OS version to install Mongodb, Nodejs, and updating firewall to install Zelflux...${NC}"
    sudo ufw allow $ZELFRONTPORT/tcp
    sudo ufw allow $ZELNODEPORT/tcp
    sudo ufw allow $LOCPORT/tcp
    if mongod --version > /dev/null 2>&1; then
        echo -e "${YELLOW}Mongodb already installed...${NC}"
        sudo systemctl start mongod
        sudo systemctl enable mongod
        install_nodejs
        mongo_backup
        mongo_logrotate
        zelflux
    else
        if [[ $(lsb_release -r) = *16.04* ]]; then
            wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
            echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
            install_mongod
            install_nodejs
            mongo_backup
            zelflux
        elif [[ $(lsb_release -r) = *18.04* ]]; then
            wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
            echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
            install_mongod
            install_nodejs
            mongo_backup
            zelflux
        elif [[ $(lsb_release -r) = *20.04* ]]; then
            wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
            echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
            install_mongod
            install_nodejs
            mongo_backup
            zelflux
        elif [[ $(lsb_release -d) = *Debian* ]] && [[ $(lsb_release -d) = *9* ]]; then
            wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
            echo "deb http://repo.mongodb.org/apt/debian stretch/mongodb-org/4.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
            install_mongod
            install_nodejs
            mongo_backup
            zelflux
        elif [[ $(lsb_release -d) = *Debian* ]] && [[ $(lsb_release -d) = *10* ]]; then
            wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
            eecho "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
            install_mongod
            install_nodejs
            mongo_backup
            zelflux
        fi
    fi
    sleep 2
}

function install_mongod() {
    sudo apt-get update
    sudo apt-get install mongodb-org -y
    sudo systemctl daemon-reload
    sudo systemctl start mongod
    sudo systemctl enable mongod
    sleep 5
    mongo_logrotate
}

function install_nodejs() {
    if ! node -v > /dev/null 2>&1; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
        . $HOME/.profile
        nvm install --lts
    else
        echo -e "${YELLOW}Nodejs already installed will skip installing it.${NC}"
    fi
}

function mongo_backup() {
    if whiptail --yesno "Would you like to bootstrap the Mongodb databases?" 9 54; then
        wget -qO- https://www.dropbox.com/s/ddznce9pp2kuup1/mongo_dump.tar.gz | tar xvz
        mongorestore dump
    fi
}

function mongo_logrotate() {
    echo -e "${YELLOW}Configuring log rotate function for Mongodb logs...${NC}"
    sleep 1
    if [ -f /etc/logrotate.d/mongolog ]; then
        echo -e "${YELLOW}Existing log rotate conf found, backing up to $HOME/mongolog.old ...${NC}"
        sudo mv /etc/logrotate.d/mongolog $HOME/mongolog.old
        sleep 2
    fi
    sudo touch /etc/logrotate.d/mongolog
    sudo chown "$USERNAME":"$USERNAME" /etc/logrotate.d/mongolog
    cat << EOF > /etc/logrotate.d/mongolog
/var/log/mongodb/*.log {
  compress
  copytruncate
  missingok
  daily
  rotate 14
}
EOF
    sudo chown root:root /etc/logrotate.d/mongolog
}

function zelflux() {
    if [ -d "./zelflux" ]; then
        sudo rm -rf zelflux
    fi
    ZELID=$(whiptail --inputbox "Enter your ZelID found in the Zelcore+/Apps section of your Zelcore" 8 71 3>&1 1>&2 2>&3)
    git clone https://github.com/zelcash/zelflux.git
    touch $HOME/zelflux/config/userconfig.js
    cat << EOF > $HOME/zelflux/config/userconfig.js
module.exports = {
      initial: {
        ipaddress: '${WANIP}',
        zelid: '${ZELID}',
        testnet: false,
      }
    }
EOF
    if ! pm2 -v > /dev/null 2>&1; then
        npm i -g pm2
        pm2_startup
    else
        pm2_startup
    fi
}

function pm2_startup() {
    pm2 startup systemd -u $USERNAME
    sudo env PATH=$PATH:/home/$USERNAME/.nvm/versions/node/$(node -v)/bin pm2 startup systemd -u $USERNAME --hp /home/$USERNAME
    pm2 start $HOME/zelflux/start.sh --name flux
    pm2 save
    sleep 2
    pm2_logrotate
}

function pm2_logrotate() {
    echo -e "${YELLOW}Configuring log rotate function for pm2 logs that's managing Zelflux...${NC}"
    if [ -d $HOME/.pm2/modules/pm2-logrotate ]; then
        echo -e "${YELLOW}Pm2-logrotate already installed will skip installation...${NC}"
        set_pm2log
    else
        pm2 install pm2-logrotate
        set_pm2log
    fi
}

function set_pm2log() {
    pm2 set pm2-logrotate:max_size 5M >/dev/null
    pm2 set pm2-logrotate:retain 6 >/dev/null
    pm2 set pm2-logrotate:compress true >/dev/null
    pm2 set pm2-logrotate:workerInterval 3600 >/dev/null
    pm2 set pm2-logrotate:rotateInterval '0 12 * * 0' >/dev/null
}

function status_loop() {
    if [ -d "/home/$USERNAME/dump" ]; then
        while true
        do
            clear
            echo -e "${YELLOW}======================================================================================"
            echo -e "${GREEN} FLUXNODE AND MONGODB IS SYNCING"
            echo -e " THIS SCREEN REFRESHES EVERY 30 SECONDS"
            echo -e " CHECK BLOCK HEIGHT AT https://explorer.runonflux.io/"
            echo -e " YOU COULD START YOUR FLUXNODE FROM YOUR CONTROL WALLET WHILE IT SYNCS"
            echo -e " MONGODB SYNCING STARTS AFTER CHAIN FULLY SYNCS PLEASE BE PATIENT"
            echo -e "${YELLOW}======================================================================================${NC}"
            echo
            $COIN_CLI getinfo
            echo
            if [[ $(wget -nv -qO - https://explorer.runonflux.io/api/status?q=getInfo | jq '.info.blocks') == $(${COIN_CLI} getinfo | jq '.blocks') ]]; then
                echo -e "${CYAN}Fluxnode on block ${GREEN}$(${COIN_CLI} getinfo | jq '.blocks')${NC}"
            else
                echo -e "${CYAN}Fluxnode on block ${BLINKRED}$(${COIN_CLI} getinfo | jq '.blocks')${NC}"
            fi
            if [[ $(wget -nv -qO - https://explorer.runonflux.io/api/status?q=getInfo | jq '.info.blocks') == $(wget -nv -qO - http://${WANIP}:16127/explorer/scannedheight | jq '.data.generalScannedHeight') ]]; then
                echo -e "${CYAN}Mongodb on block ${GREEN}$(wget -nv -qO - http://${WANIP}:16127/explorer/scannedheight | jq '.data.generalScannedHeight')${NC}"
            else
                echo -e "${CYAN}Mongodb on block ${BLINKRED}$(wget -nv -qO - http://${WANIP}:16127/explorer/scannedheight | jq '.data.generalScannedHeight')${NC}"
            fi
            sleep 2
            echo
            NUM='30'
            MSG1="${CYAN}Refreshes every 30 seconds while syncing chain and data. Refresh loop will stop automatically once it's fully synced.${NC}"
            MSG2=''
            spinning_timer
            if [[ $(wget -nv -qO - https://explorer.runonflux.io/api/status?q=getInfo | jq '.info.blocks') == $(${COIN_CLI} getinfo | jq '.blocks') ]] && [[ $(wget -nv -qO - http://${WANIP}:16127/explorer/scannedheight | jq '.data.generalScannedHeight') == $(wget -nv -qO - https://explorer.zel.network/api/status?q=getInfo | jq '.info.blocks') ]]; then
                break
            fi
        done
        rm -rf dump && sleep 3
        fluxbench-cli restartnodebenchmarks > /dev/null 2>&1
        check
        display_banner
    else
        while true
        do
            clear
            echo -e "${YELLOW}======================================================================================"
            echo -e "${GREEN} FLUXNODE IS SYNCING"
            echo -e " THIS SCREEN REFRESHES EVERY 30 SECONDS"
            echo -e " CHECK BLOCK HEIGHT AT https://explorer.runonflux.io/"
            echo -e " YOU COULD START YOUR FLUXNODE FROM YOUR CONTROL WALLET WHILE IT SYNCS"
            echo -e "${YELLOW}======================================================================================${NC}"
            echo
            $COIN_CLI getinfo
            sudo chown -R "$USERNAME":"$USERNAME" $HOME
            NUM='30'
            MSG1="${CYAN}Refreshes every 30 seconds while syncing to chain. Refresh loop will stop automatically once it's fully synced.${NC}"
            MSG2=''
            spinning_timer
            if [[ $(wget -nv -qO - https://explorer.runonflux.io/api/status?q=getInfo | jq '.info.blocks') == $(${COIN_CLI} getinfo | jq '.blocks') ]]; then
                break
            fi
        done
        check
        display_banner
    fi
}

function update_script() {
    echo -e "${YELLOW}Creating a script to update binaries for future updates...${NC}"
    touch $HOME/update.sh
    cat << EOF > $HOME/update.sh
#!/bin/bash
COIN_NAME='flux'
COIN_DAEMON='fluxd'
COIN_CLI='flux-cli'
COIN_PATH='/usr/local/bin'
sudo systemctl stop \$COIN_NAME
\$COIN_CLI stop > /dev/null 2>&1 && sleep 2
sudo killall \$COIN_DAEMON > /dev/null 2>&1
sudo killall -s SIGKILL fluxbenchd > /dev/null 2>&1
sudo apt-get update
sudo apt-get install --only-upgrade \$COIN_NAME -y
sudo chmod 755 \${COIN_PATH}/\${COIN_NAME}*
sudo systemctl start \$COIN_NAME > /dev/null 2>&1
EOF
    sudo chmod +x update.sh
}

function check() {
    echo && echo && echo
    echo -e "${YELLOW}Running through some checks...${NC}"
    if pgrep fluxd > /dev/null; then
        echo -e "${CHECK_MARK} ${CYAN}${COIN_NAME^} daemon is installed and running${NC}" && sleep 1
    else
        echo -e "${X_MARK} ${CYAN}${COIN_NAME^} daemon is not running${NC}" && sleep 1
    fi
    if [ -d "$HOME/.zcash-params" ]; then
        echo -e "${CHECK_MARK} ${CYAN}zkSNARK params installed${NC}" && sleep 1
    else
        echo -e "${X_MARK} ${CYAN}zkSNARK params not installed${NC}" && sleep 1
    fi
    if docker -v > /dev/null; then
        echo -e "${CHECK_MARK} ${CYAN}Docker is installed${NC}" && sleep 1
    else
        echo -e "${X_MARK} ${CYAN}Docker is not install${NC}" && sleep 1
    fi
    if groups $USERNAME | grep docker > /dev/null; then
        echo -e "${CHECK_MARK} ${CYAN}${USERNAME} is in the docker group${NC}" && sleep 1
    else
        echo -e "${X_MARK} ${CYAN}${USERNAME} is not in the docker group${NC}" && sleep 1
    fi
    if pgrep mongod > /dev/null; then
        echo -e "${CHECK_MARK} ${CYAN}Mongodb is installed and running${NC}" && sleep 1
    else
        echo -e "${X_MARK} ${CYAN}Mongodb is not running or failed to install${NC}" && sleep 1
    fi
    if node -v > /dev/null 2>&1; then
        echo -e "${CHECK_MARK} ${CYAN}Nodejs installed${NC}" && sleep 1
    else
        echo -e "${X_MARK} ${CYAN}Nodejs did not install${NC}" && sleep 1
    fi
    if [ -d "$HOME/zelflux" ]; then
        echo -e "${CHECK_MARK} ${CYAN}Zelflux installed${NC}" && sleep 1
    else
        echo -e "${X_MARK} ${CYAN}Zelflux did not install${NC}" && sleep 1
    fi
    if [ -f "$HOME/$UPDATE_FILE" ]; then
        echo -e "${CHECK_MARK} ${CYAN}Update script created${NC}" && sleep 3
    else
        echo -e "${X_MARK} ${CYAN}Update script not installed${NC}" && sleep 3
    fi
    echo && echo && echo
}

function display_banner() {
    echo -e "${BLUE}"
    figlet -t -k "FLUXNODES"
    echo -e "${NC}"
    echo -e "${YELLOW}================================================================================================================================"
    echo -e " PLEASE COMPLETE THE FLUXNODE SETUP AND START YOUR FLUXNODE${NC}"
    echo -e "${CYAN} COURTESY OF DK808${NC}"
    echo
    echo -e "${YELLOW}   Commands to manage ${COIN_NAME}.${NC}"
    echo -e "${PIN} ${CYAN}TO START: ${SEA}${COIN_DAEMON}${NC}"
    echo -e "${PIN} ${CYAN}TO STOP : ${SEA}${COIN_CLI} stop${NC}"
    echo -e "${PIN} ${CYAN}RPC LIST: ${SEA}${COIN_CLI} help${NC}"
    echo
    echo -e "${PIN} ${YELLOW}To update binaries wait for announcement that update is ready then enter:${NC} ${SEA}./${UPDATE_FILE}${NC}"
    echo
    echo -e "${YELLOW}   PM2 is now managing Flux to start up on reboots.${NC}"
    pm2 list
    echo
    echo -e "${PIN} ${CYAN}To access your Flux UI enter this in as your url: ${BLINKSEA}${WANIP}:${ZELFRONTPORT}${NC}"
    echo -e "${YELLOW}================================================================================================================================${NC}"
}

#
#end of functions

#run functions
wipe_clean
ssh_port
ip_confirm
create_swap
install_packages
create_conf
install_zel
zk_params
bootstrap
create_service
basic_security
start_daemon
install_zelflux
log_rotate
update_script
status_loop

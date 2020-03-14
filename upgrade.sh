#!/bin/bash

###### you must be logged in as a sudo user, not root #######

COIN_NAME='zelcash'

#wallet information

UPDATE_FILE='update.sh'
CONFIG_DIR='.zelcash'
CONFIG_FILE='zelcash.conf'
COIN_DAEMON='zelcashd'
COIN_CLI='zelcash-cli'
COIN_PATH='/usr/local/bin'
USERNAME="$(whoami)"

#Zelflux ports
ZELFRONTPORT=16126
LOCPORT=16127
ZELNODEPORT=16128
MDBPORT=27017


#color codes
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE="\\033[38;5;27m"
SEA="\\033[38;5;49m"
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

#emoji codes
CHECK_MARK="${GREEN}\xE2\x9C\x94${NC}"
X_MARK="${RED}\xE2\x9D\x8C${NC}"
PIN="${RED}\xF0\x9F\x93\x8C${NC}"

#end of required details
#

echo -e "${YELLOW}====================================================================="
echo -e " Kamata Upgrade"
echo -e "=====================================================================${NC}"
echo -e "${CYAN}MAR 2020, created by dk808 from Zel's team and AltTank Army."
echo -e "Upgrade starting, press [CTRL+C] to cancel.${NC}"
sleep 5
if [ "$USERNAME" = "root" ]; then
    echo -e "${CYAN}You are currently logged in as ${GREEN}root${CYAN}, please switch to the username you just created.${NC}"
    sleep 4
    exit
fi

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

function kill_daemon() {
    echo -e "${YELLOW}Removing any instances of ${COIN_NAME^}${NC}"
    sudo systemctl stop $COIN_NAME > /dev/null 2>&1 && sleep 3
    $COIN_CLI stop > /dev/null 2>&1 && sleep 2
    sudo killall $COIN_DAEMON > /dev/null 2>&1
    rm zelnodeupdate.sh > /dev/null 2>&1
    rm zelnodev5.sh > /dev/null 2>&1
    rm zelnodev4.0.sh > /dev/null 2>&1
    sudo apt-get install jq -y
}

function append_conf() {
    echo -e "${YELLOW}Appending conf file with required info...${NC}"
    zelnodeoutpoint=$(whiptail --title "ZELNODE OUTPOINT" --inputbox "Enter your Zelnode collateral txid" 8 72 3>&1 1>&2 2>&3)
    zelnodeindex=$(whiptail --title "ZELNODE INDEX" --inputbox "Enter your Zelnode collateral output index usually a 0/1" 8 60 3>&1 1>&2 2>&3)
    echo "rpcallowip=172.18.0.1" >> ~/$CONFIG_DIR/$CONFIG_FILE
    echo zelnodeoutpoint=$zelnodeoutpoint >> ~/$CONFIG_DIR/$CONFIG_FILE
    echo zelnodeindex=$zelnodeindex >> ~/$CONFIG_DIR/$CONFIG_FILE
}

function zel_package() {
    sudo apt-get update
    sudo apt install zelcash zelbench -y
    sudo chmod 755 $COIN_PATH/${COIN_NAME}*
}

function update_zel() {
    echo -e "${YELLOW}Update Zel and install Zelbench...${NC}"
    if ! gpg --list-keys Zel > /dev/null; then
    	echo 'deb https://apt.zel.cash/ all main' | sudo tee /etc/apt/sources.list.d/zelcash.list
	gpg --keyserver keyserver.ubuntu.com --recv 4B69CA27A986265D
	gpg --export 4B69CA27A986265D | sudo apt-key add -
	zel_package && sleep 2
	if ! gpg --list-keys Zel > /dev/null; then
	    gpg --keyserver na.pool.sks-keyservers.net --recv 4B69CA27A986265D
	    gpg --export 4B69CA27A986265D | sudo apt-key add -
	    zel_package && sleep 2
	    if ! gpg --list-keys Zel > /dev/null; then
	    	gpg --keyserver eu.pool.sks-keyservers.net --recv 4B69CA27A986265D
		gpg --export 4B69CA27A986265D | sudo apt-key add -
		zel_package && sleep 2
		if ! gpg --list-keys Zel > /dev/null; then
		    gpg --keyserver pgpkeys.urown.net --recv 4B69CA27A986265D
		    gpg --export 4B69CA27A986265D | sudo apt-key add -
		    zel_package && sleep 2
		    if ! gpg --list-keys Zel > /dev/null; then
		    	gpg --keyserver keys.gnupg.net --recv 4B69CA27A986265D
			gpg --export 4B69CA27A986265D | sudo apt-key add -
			zel_package && sleep 2
		    else
		    	zel_package && sleep 2
		    fi
		fi
	    fi
	fi
    fi
}

function start_daemon() {
    NUM='105'
    MSG1='Starting daemon & syncing with chain please be patient this will take about 2 min...'
    MSG2=''
    if $COIN_DAEMON > /dev/null 2>&1; then
    	echo && spinning_timer
	NUM='10'
	MSG1='Getting info...'
	MSG2="${CHECK_MARK}"
	echo && spinning_timer
	echo
	$COIN_CLI getinfo
	sleep 5
    else
    	echo -e "${RED}Something is not right the daemon did not start. Will exit out so try and run the script again.${NC}"
	exit
    fi
}

function log_rotate() {
    echo -e "${YELLOW}Configuring log rotate function for debug logs...${NC}"
    sleep 1
    if [ -f /etc/logrotate.d/zeldebuglog ]; then
    	echo -e "${YELLOW}Existing log rotate conf found, backing up to ~/zeldebuglogrotate.old ...${NC}"
	sudo mv /etc/logrotate.d/zeldebuglog ~/zeldebuglogrotate.old;
	sleep 2
    fi
    	sudo touch /etc/logrotate.d/zeldebuglog
	sudo chown "$USERNAME":"$USERNAME" /etc/logrotate.d/zeldebuglog
	cat << EOF > /etc/logrotate.d/zeldebuglog
/home/$USERNAME/.zelcash/debug.log {
  compress
  copytruncate
  missingok
  weekly
  rotate 4
}

/home/$USERNAME/.zelbenchmark/debug.log {
  compress
  copytruncate
  missingok
  monthly
  rotate 2
}
EOF
    sudo chown root:root /etc/logrotate.d/zeldebuglog
}

function ip_confirm() {
    echo -e "${YELLOW}Detecting IP address being used...${NC}" && sleep 1
    WANIP=$(wget http://ipecho.net/plain -O - -q)
    whiptail --yesno "Detected IP address is $WANIP is this correct?" 8 60
    if [ $? = 1 ]; then
    	WANIP=$(whiptail --inputbox "        Enter IP address" 8 36 3>&1 1>&2 2>&3)
    fi
}

function kill_sessions() {
    echo -e "${YELLOW}Detecting sessions please remove any that is running Zelflux...${NC}" && sleep 5
    tmux ls | sed -e 's/://g' | cut -d' ' -f 1 | tee tempfile > /dev/null 2>&1
    grep -v '^ *#' < tempfile | while IFS= read -r line
    do
    	if whiptail --yesno "Would you like to kill session ${line}?" 8 43; then
	    tmux kill-sess -t "$line"
	fi
    done
    rm tempfile
}

function install_zelflux() {
    echo -e "${YELLOW}Detect OS version to install Mongodb, Nodejs, and updating firewall to install Zelflux...${NC}"
    sudo ufw allow $ZELFRONTPORT/tcp
    sudo ufw allow $LOCPORT/tcp
    sudo ufw allow $ZELNODEPORT/tcp
    sudo ufw allow $MDBPORT/tcp
    if [[ $(lsb_release -r) = *16.04* ]]; then
    	wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
	echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
	install_mongod
	install_nodejs
	zelflux
    elif [[ $(lsb_release -r) = *18.04* ]]; then
    	wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
	echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
	install_mongod
	install_nodejs
	zelflux
    elif [[ $(lsb_release -d) = *Debian* ]] && [[ $(lsb_release -d) = *9* ]]; then
    	wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
	echo "deb [ arch=amd64 ] http://repo.mongodb.org/apt/debian stretch/mongodb-org/4.2 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
	install_mongod
	install_nodejs
	zelflux
    elif [[ $(lsb_release -d) = *Debian* ]] && [[ $(lsb_release -d) = *10* ]]; then
    	wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
	echo "deb [ arch=amd64 ] http://repo.mongodb.org/apt/debian buster/mongodb-org/4.2 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
	install_mongod
	install_nodejs
	zelflux
    fi
    sleep 2
}

function install_mongod() {
    sudo apt-get update
    sudo apt-get install mongodb-org -y
    sudo service mongod start
}

function install_nodejs() {
    if ! node -v > /dev/null 2>&1; then
    	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.0/install.sh | bash
	. ~/.profile
	nvm install --lts
    else
    	echo -e "${YELLOW}Nodejs already installed will skip installing it.${NC}"
    fi
}

function zelflux() {
    if [ -d "./zelflux" ]; then
    	sudo rm -rf zelflux
    fi
    kill_sessions
    if whiptail --yesno "If you would like admin privileges to Zelflux select <Yes>(Recommended) and prepare to enter your ZelID. If you don't have one or don't want to have admin privileges to Zelflux select <No>." 9 108; then
    	ZELID=$(whiptail --inputbox "Enter your ZelID found in the Zelcore+/Apps section of your Zelcore" 8 71 3>&1 1>&2 2>&3)
    else
    	ZELID='132hG26CFTNhLM3MRsLEJhp9DpBrK6vg5N'
    fi
    TMUX=$(whiptail --inputbox "Enter a name for your tmux session to run Zelflux" 8 53 3>&1 1>&2 2>&3)
    if ! tmux ls | grep -q "$TMUX"; then
    	tmux new-session -d -s "$TMUX"
	tmux send-keys 'git clone https://github.com/zelcash/zelflux.git && cd zelflux && npm start' C-m
	NUM='300'
	MSG1="Cloning and installing Zelflux. Please be patient this will take 5 min..."
	MSG2="${CHECK_MARK}${CHECK_MARK}${CHECK_MARK}${GREEN} installation has completed${NC}"
	echo && spinning_time
	sleep 2
	tmux send-keys "$WANIP" C-m
	sleep 2
	tmux send-keys "$ZELID" C-m
	sleep 2
	SESSION_NAME="$TMUX"
    else
    	tmux new-session -d -s ${COIN_NAME^}
	tmux send-keys 'git clone https://github.com/zelcash/zelflux.git && cd zelflux && npm start' C-m
	NUM='300'
	MSG1="Cloning and installing Zelflux. Please be patient this will take 5 min..."
	MSG2="${CHECK_MARK}${CHECK_MARK}${CHECK_MARK}${GREEN} installation has completed${NC}"
	echo && spinning_timer
	sleep 2
	tmux send-keys "$WANIP" C-m
	sleep 2
	tmux send-keys "$ZELID" C-m
	sleep 2
	SESSION_NAME="${COIN_NAME^}"
    fi
}

function status_loop() {
    while true
    do
    	clear
	echo -e "${YELLOW}======================================================================================"
	echo -e "${GREEN} ZELNODE IS SYNCING"
	echo -e " THIS SCREEN REFRESHES EVERY 30 SECONDS"
	echo -e " CHECK BLOCK HEIGHT AT https://explorer.zel.cash/"
	echo -e " YOU COULD START YOUR ZELNODE FROM YOUR CONTROL WALLET WHILE IT SYNCS"
	echo -e "${YELLOW}======================================================================================${NC}"
	echo
	$COIN_CLI getinfo
	sudo chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"
	NUM='30'
	MSG1="${CYAN}Refreshes every 30 seconds while syncing to chain. Refresh loop will stop automatically once it's fully synced.${NC}"
	MSG2=''
	spinning_timer
	if [[ $(wget -nv -qO - https://explorer.zel.cash/api/status?q=getInfo | jq '.info.blocks') == $(${COIN_CLI} getinfo | jq '.blocks') ]]; then
	    break
	fi
    done
    check
    display_banner
}

function update_script() {
    echo -e "${YELLOW}Creating a script to update binaries for future updates...${NC}"
    touch /home/"$USERNAME"/update.sh
    cat << EOF > /home/"$USERNAME"/update.sh
#!/bin/bash
COIN_NAME='zelcash'
COIN_DAEMON='zelcashd'
COIN_CLI='zelcash-cli'
COIN_PATH='/usr/local/bin'
\$COIN_CLI stop > /dev/null 2>&1 && sleep 2
sudo killall \$COIN_DAEMON > /dev/null 2>&1
sudo apt-get update
sudo apt-get install --only-upgrade \$COIN_NAME -y
sudo chmod 755 \${COIN_PATH}/\${COIN_NAME}*
\$COIN_DAEMON > /dev/null 2>&1
EOF
    sudo chmod +x update.sh
}

function restart_script() {
    echo -e "${YELLOW}Creating a script to restart Zelflux in case server reboots...${NC}"
    touch /home/"$USERNAME"/restart_zelflux.sh
    cat << EOF > /home/"$USERNAME"/restart_zelflux.sh
#!/bin/bash
sudo service mongod start && sleep 5
tmux new-session -d -s ${SESSION_NAME}
tmux send-keys -t ${SESSION_NAME} "cd zelflux && npm start" C-m
EOF
    sudo chmod +x restart_zelflux.sh
    crontab -l | grep -v "SHELL=/bin/bash" | crontab -
    crontab -l | grep -v "pgrep mongod > /dev/null || /home/$USERNAME/restart_zelflux.sh" | crontab -
    sleep 1
    crontab -l > tempcron
    echo "SHELL=/bin/bash" >> tempcron
    echo "* * * * * pgrep mongod > /dev/null || /home/$USERNAME/restart_zelflux.sh >/dev/null 2>&1" >> tempcron
    crontab tempcron
    rm tempcron
}

function check() {
    echo && echo && echo
    echo -e "${YELLOW}Running through some checks...${NC}"
    if pgrep zelcashd > /dev/null; then
    	echo -e "${CHECK_MARK} ${CYAN}${COIN_NAME^} daemon is installed and running${NC}" && sleep 1
    else
    	echo -e "${X_MARK} ${CYAN}${COIN_NAME^} daemon is not running${NC}" && sleep 1
    fi
    if [ -d "/home/$USERNAME/.zcash-params" ]; then
    	echo -e "${CHECK_MARK} ${CYAN}zkSNARK params installed${NC}" && sleep 1
    else
    	echo -e "${X_MARK} ${CYAN}zkSNARK params not installed${NC}" && sleep 1
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
    if [ -d "/home/$USERNAME/zelflux" ]; then
    	echo -e "${CHECK_MARK} ${CYAN}Zelflux installed${NC}" && sleep 1
    else
    	echo -e "${X_MARK} ${CYAN}Zelflux did not install${NC}" && sleep 1
    fi
    if [ -f "/home/$USERNAME/$UPDATE_FILE" ]; then
    	echo -e "${CHECK_MARK} ${CYAN}Update script created${NC}" && sleep 3
    else
    	echo -e "${X_MARK} ${CYAN}Update script not installed${NC}" && sleep 3
    fi
    if [ -f "/home/$USERNAME/restart_zelflux.sh" ]; then
    	echo -e "${CHECK_MARK} ${CYAN}Restart script for Zelflux created${NC}" && sleep 3
    else
    	echo -e "${X_MARK} ${CYAN}Restart script not installed${NC}" && sleep 3
    fi
    echo && echo && echo
}

function display_banner() {
    echo -e "${BLUE}"
    figlet -t -k "ZELNODES  &  ZELFLUX"
    echo -e "${NC}"
    echo -e "${YELLOW}================================================================================================================================"
    echo -e " PLEASE RESTART YOUR ZELNODE FROM ZELCORE/ZELMATE${NC}"
    echo -e "${CYAN} COURTESY OF DK808${NC}"
    echo
    echo -e "${YELLOW}   Commands to manage ${COIN_NAME}. Note that you have to be in the zelcash directory when entering commands.${NC}"
    echo -e "${PIN} ${CYAN}TO START: ${SEA}${COIN_DAEMON}${NC}"
    echo -e "${PIN} ${CYAN}TO STOP : ${SEA}${COIN_CLI} stop${NC}"
    echo -e "${PIN} ${CYAN}RPC LIST: ${SEA}${COIN_CLI} help${NC}"
    echo
    echo -e "${PIN} ${YELLOW}To update binaries wait for announcement that update is ready then enter:${NC} ${SEA}./${UPDATE_FILE}${NC}"
    echo
    echo -e "${YELLOW}   Your tmux session running Zelflux is named ${SESSION_NAME}${NC}"
    echo -e "${PIN} ${CYAN}To attach to zelflux session enter: ${SEA}tmux a -t ${SESSION_NAME}${NC}"
    echo -e "${PIN} ${CYAN}To detach zelflux session enter: ${SEA}Ctrl+b, d${NC}"
    echo -e "${PIN} ${CYAN}To kill zelflux session enter: ${SEA}tmux kill-session -t ${SESSION_NAME}${NC}"
    echo
    echo -e "${PIN} ${CYAN}To access your frontend to Zelflux enter this in as your url: ${SEA}${WANIP}:${ZELFRONTPORT}${NC}"
    echo -e "${YELLOW}================================================================================================================================${NC}"
}

#
#end of functions

#run functions
    create_swap
    kill_daemon
    append_conf
    update_zel
    start_daemon
    log_rotate
    ip_confirm
    install_zelflux
    update_script
    restart_script
    status_loop

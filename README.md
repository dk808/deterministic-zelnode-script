# Zelnode and Zelflux
Script needs to be ran under a non-root user with sudo privileges. It will build using zel apt packages and should work on Ubuntu 18 and Debian 10. Script will install firewall, daemon service, create update script, create zelflux start script, and use pm2 to manage Zelflux on server restarts/reboots. You could find a detailed guide in the [Wiki](https://github.com/dk808/deterministic-zelnode-script/wiki).

**_Note: All test runs of this install script have only been done on VPS platforms and most likely will not work on personal home servers. USE AT OWN RISK._** 

## Docker Instructions
After creating a root user with sudo privileges to run your zel daemon, run the following commands while still in root.

1.  sudo apt-get update
2.  sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
3.  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
4.  sudo apt-get update
5.  sudo apt-get install docker-ce docker-ce-cli containerd.io -y
6.  adduser USER docker        **_#(Replace USER with the username you created e.g adduser dk808 docker)_**
7.  reboot

Give server few min to restart, log back in as the user that you created above, and then run the script posted below.

User input will be prompted so have in hand the following.
1.  zelnodeprivkey
2.  Collateral txid
3.  Collateral output index usually 0/1
4.  Your ZelID for Zelflux

**_Note: Your ZelID is not your Zelcore username. Please check [Wiki guide](https://github.com/dk808/deterministic-zelnode-script/wiki) for more info._**

```
bash -i <(curl -s https://raw.githubusercontent.com/dk808/deterministic-zelnode-script/master/install.sh)
```

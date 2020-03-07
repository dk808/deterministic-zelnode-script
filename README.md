# Zelnode and Zelflux
Script needs to be ran under a non-root user with sudo privileges. It will build using zel apt packages and should work on Ubuntu 18 and Debian 10. Script will install firewall, daemon service, create update script, create zelflux restart script, and set cron job to run the restart script if is not running. USE AT OWN RISK. You could find a detailed guide in the [Wiki](https://github.com/dk808/deterministic-zelnode-script/wiki)

## Docker Instructions
After creating a non-root user to run your zel daemon, run the following commands as the root user.

1.  apt update && apt install snapd -y
2.  snap install docker
3.  groupadd docker
4.  adduser USER docker        *#(Replace USER with the username you just created)*
5.  reboot

Once the server has finished restarting, log back in as the user that you created above and then run the script posted below

User input will be prompted so have in hand the following.
1.  zelnodeprivkey
2.  Collateral txid
3.  Collateral output index usually 0/1
4.  Your ZelID for Zelflux installation

```
bash -i <(curl -s https://raw.githubusercontent.com/dk808/deterministic-zelnode-script/master/install.sh)
```

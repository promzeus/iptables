### IPTABLES
Automatic iptables for docker swarm with blocking the smovol opening of ports to the world. \
When adding a new service to Docker Swarm, for example, 0.0.0.0 or restarting dockerd, bypasses the -I FORWARD 1 ..... lock
therefore, my script needs to be run every 5 minutes for example.
```
*/5 * * * * /bin/bash /etc/iptables.sh > /dev/null 2>&1
```

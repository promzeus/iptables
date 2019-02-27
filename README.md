### IPTABLES
`/etc/iptables.sh` \
Automatic iptables for docker swarm with blocking the unauthorized opening of ports to the world. \
When adding a new service to Docker Swarm, for example, 0.0.0.0.l000 or restarting dockerd, swarm bypasses the -I FORWARD 1 ..... lock and opens the ports above the blocking rule.\
Therefore, my script needs to be run every 5 minutes for example.
```
*/5 * * * * /bin/bash /etc/iptables.sh > /dev/null 2>&1
```

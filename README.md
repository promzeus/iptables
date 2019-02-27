### IPTABLES
`/etc/iptables.sh` \
Automatic iptables for docker swarm with blocking the unauthorized opening of ports to the world. \
When adding a new service to Docker Swarm, for example, 0.0.0.0:5000 or restarting dockerd, swarm bypasses the -I FORWARD 1 ..... lock and opens the ports above the blocking rule.\
Therefore, my script needs to be run every 5 minutes for example.
```
*/5 * * * * /bin/bash /etc/iptables.sh > /dev/null 2>&1
```
Every time the script is run, iptables is checked for changes in iptables using diff, if there are no changes, the script is not executed, it makes EXIT: iptables - Nothing to do, exiting...
```
#============= Check Change ============
echo '*nat' > /etc/ipt_docker_rules
$IPT -t nat -S >> /etc/ipt_docker_rules
echo 'COMMIT' >> /etc/ipt_docker_rules
echo '*filter' >> /etc/ipt_docker_rules
$IPT -t filter -S >> /etc/ipt_docker_rules
echo 'COMMIT' >> /etc/ipt_docker_rules
if [ "$1" = "-f" ]; then
    /bin/rm -f /etc/ipt_docker_rules.old
fi
if [ -f "/etc/ipt_docker_rules.old" ]; then
    if [ -z "`/usr/bin/diff /etc/ipt_docker_rules /etc/ipt_docker_rules.old`" ]; then
        echo "iptables - Nothing to do, exiting..."
        exit
    fi
fi
/bin/cp /etc/ipt_docker_rules /etc/ipt_docker_rules.old
```
To run the script manually, use the `-f` option. \
All chains have their alias:
```
z_INPUT
z_FORWARD
z_POSTROUTING
z_PREROUTNG
```
this is done so that no duplicate rules occur, and so that when you clear the old rules, the docker rules are not deleted.
Be sure to use alias.

Это для всех devops в чатах telegram у котрых я спрашивал как мне решить эту проблему? мне сказали нет решений или они все костыльные и не рабочие. Получайте рабочее решение! \
Надеюсь это комуто поможет. Удачи.

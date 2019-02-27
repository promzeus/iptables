#!/bin/bash

INET_IF="eth0"
INET_IP="20.20.20.20"
PROD_IF="eth1.100"
PROD_IP="172.16.10.8"
PROD_NET="172.16.10.0/24"
IPT=/sbin/iptables
IPTREST=/sbin/iptables-restore
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
#==============CLEAR RULES==============
$IPT -F port-scanning
$IPT -F syn_flood
$IPT -F LOGGING
$IPT -F z_INPUT
$IPT -F z_FORWARD
$IPT -t nat -F z_POSTROUTING
$IPT -t nat -F z_PREROUTING
# clear z_* link
while ($IPT-save | grep -e "-A INPUT -j z_INPUT"); do
    $IPT -D INPUT -j z_INPUT
done
while ($IPT-save | grep -e "-A FORWARD -j z_FORWARD"); do
    $IPT -D FORWARD -j z_FORWARD
done
while ($IPT-save | grep -e "-A POSTROUTING -j z_POSTROUTING"); do
    $IPT -t nat -D POSTROUTING -j z_POSTROUTING
done
while ($IPT-save | grep -e "-A PREROUTING -j z_PREROUTING"); do
    $IPT -t nat -D PREROUTING -j z_PREROUTING
done
#
$IPT -X port-scanning
$IPT -X syn_flood
$IPT -X LOGGING
$IPT -X z_INPUT
$IPT -X z_FORWARD
$IPT -t nat -X z_POSTROUTING
$IPT -t nat -X z_PREROUTING
# create link
$IPT -N port-scanning
$IPT -N syn_flood
$IPT -N LOGGING
$IPT -N z_INPUT
$IPT -N z_FORWARD
$IPT -t nat -N z_POSTROUTING
$IPT -t nat -N z_PREROUTING
# global
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT
#
$IPT -A INPUT -j z_INPUT
$IPT -I FORWARD 1 -j z_FORWARD
$IPT -t nat -A POSTROUTING -j z_POSTROUTING
$IPT -t nat -A PREROUTING -j z_PREROUTING
#################################### DROP FORWARD DOCKER SWARM ########################################
$IPT -A z_FORWARD -i $INET_IF -m conntrack --ctstate NEW -p tcp --dport 0:65535 -j DROP
$IPT -A z_FORWARD -i $INET_IF -m conntrack --ctstate NEW -p udp --dport 0:65535 -j DROP
#######################################################################################################
#$IPT -A z_FORWARD -i $VRACK_IF  -j ACCEPT
#$IPT -A z_FORWARD -s $VRACK_NET -j ACCEPT
$IPT -A z_FORWARD -i $PROD_IF -j ACCEPT
$IPT -A z_FORWARD -s $PROD_NET -j ACCEPT
$IPT -A z_FORWARD -i lo -j ACCEPT
$IPT -A z_FORWARD -s 127.0.0.1 -j ACCEPT
$IPT -A z_FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
#=======================================
#$IPT -A z_INPUT -i $VRACK_IF -s $VRACK_NET -j ACCEPT
$IPT -A z_INPUT -i $PROD_IF -s $PROD_NET -j ACCEPT
$IPT -A z_INPUT -i lo -j ACCEPT
$IPT -A z_INPUT ! -i lo -d 127.0.0.0/8 -j REJECT
$IPT -A z_INPUT -i docker_gwbridge -j ACCEPT
$IPT -A z_INPUT -i docker0 -j ACCEPT
$IPT -A z_INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
#
#$IPT -A z_INPUT -p tcp -m multiport --dport 80,443 -j ACCEPT
$IPT -I z_FORWARD 1 -i $INET_IF -p tcp -m multiport --dport 80,443 -j ACCEPT
################### ipsec ####################
#$IPT -A z_INPUT -p gre -j ACCEPT
#$IPT -A z_OUTPUT -p gre -j ACCEPT
#$IPT -t nat -A z_POSTROUTING -s $OFFICE_NET -j SNAT --to-source $VRACK_IP		    	# IPSEC office
#$IPT -t nat -A z_POSTROUTING -o $INET_IF -m policy --dir out --pol ipsec -j ACCEPT		# ИСКЛЮЧАЕМ IPSEC из маскарада.
################### inet ##########################
#$IPT -t nat -A z_POSTROUTING -s $VRACK_NET -o $INET_IF -j MASQUERADE
#$IPT -t nat -A z_POSTROUTING -s $PROD_NET -o $INET_IF -j MASQUERADE
#################### snat for lxc container ###############
#$IPT -t nat -A z_POSTROUTING -o $VRACK_IF -d $VRACK_NET -j SNAT --to-source $VRACK_IP
#$IPT -t nat -A z_POSTROUTING -o $PROD_IF -d $PROD_NET -j SNAT --to-source $PROD_IP

# prerouting  ports
#$IPT -I z_FORWARD 1 -i $INET_IF -o $DEV_IF -d 172.16.97.110 -p udp -m udp --dport 5188 -j ACCEPT
#$IPT -t nat -A z_PREROUTING -d $INET_IP -p udp -m udp --dport 5188 -j DNAT --to-destination 172.16.97.110:5188	#Openvpn
######################################################################################################################
#Protection against port scanning
$IPT -A port-scanning -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s --limit-burst 2 -j RETURN
$IPT -A port-scanning -j DROP

#Syn-flood protection
$IPT -A z_INPUT -p tcp --syn -j syn_flood
$IPT -A syn_flood -m limit --limit 1/s --limit-burst 3 -j RETURN
$IPT -A syn_flood -j DROP
$IPT -A z_INPUT -p icmp -m limit --limit  1/s --limit-burst 1 -j ACCEPT
$IPT -A z_INPUT -p icmp -m limit --limit 1/s --limit-burst 1 -j LOG --log-prefix PING-DROP:
$IPT -A z_INPUT -p icmp -j DROP

#Logging
$IPT -A z_INPUT -j LOGGING
$IPT -A LOGGING -m limit --limit 2/min -j LOG --log-prefix "$IPT Packet Dropped: " --log-level 7
$IPT -A LOGGING -j DROP


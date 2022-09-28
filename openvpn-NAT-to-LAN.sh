#!/bin/bash

#Script to NAT to/from a local LAN (e.g. home network) into an OpenVPN server running away (cloud)
#Objective: to have server/s in cloud appear in local network as local nodes (NAT 1:1)


#modify this value to match the address to be reached in home network as a gateway to the LAN
#this is the LAN interface of the host running OpenVPN server
export HOME_NET=192.168.86.24/24   #PRIVATE_ADDRESS_ONPREM=192.168.1.2

#modify this value to match the address of the remote cloud client's LAN interface
export CLOUD_NET_GW=10.150.0.42

#interface names in the OpenVPN LAN server
export INTERNAL_IF=enp2s0f1 #TO_LAN
export EXTERNAL_IF=openvpn_server #TO_VPN

#enable ip forwarding on this host
#this should have been done already on the GUI to get things working
#echo 1 > /proc/sys/net/ipv4/ip_forward

#enable traffic from openvpn to LAN: TCP on ports 80 and 443
iptables -A FORWARD -i $EXTERNAL_IF -o $INTERNAL_IF -p tcp --syn --dport 80 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i $EXTERNAL_IF -o $INTERNAL_IF -p tcp --syn --dport 443 -m conntrack --ctstate NEW -j ACCEPT

#enable returning traffic from established connections on both directions
iptables -A FORWARD -i $EXTERNAL_IF -o $INTERNAL_IF -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i $INTERNAL_IF -o $EXTERNAL_IF -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#DNAT: swap destination address on traffic from VPN to/from LAN
iptables -t nat -A PREROUTING -i $EXTERNAL_IF -p tcp --dport 80 -j DNAT  --to-destination $HOME_NET
iptables -t nat -A PREROUTING -i $EXTERNAL_IF -p tcp --dport 443 -j DNAT  --to-destination $HOME_NET

#SNAT: swap source address on traffic to/from onprem
iptables -t nat -A POSTROUTING -o $INTERNAL_IF -j MASQUERADE

#Add the below route to reach the on-prem instance.
ip route add $HOME_NET via $CLOUD_NET_GW dev $INTERNAL_IF


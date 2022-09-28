#!/bin/bash

#Script to NAT to/from an OpenVPN Server running in local LAN (e.g. home network) we call SERVER_NET
# into an OpenVPN client running away (cloud) in a remote CLIENT_NET
#Objective: to have client/s in cloud appear as local nodes in server (home) network (NAT 1:1)
#This runs on the OPEN_SERVER that runs in the SERVER_NET (home net usually)

#
#  [CLIENT_NET]--(client_net_gw)(ovpn_client)--OVPNTUN--(ovpn_server)(server_net_gw)--[SERVER_NET]
#      ^^                      ^^^                ^^                ^^^                   ^^^
#   usually_VPC       usually_a_VM_in_Cloud    internet    usually_a_server_home       home_net(192.168...)
#

#ISSUE: Server network hosts (behind openvpn server) don't know how to reach the CLIENT_GW or the CLIENT_NET

#modify this value to match the address to be reached in home network as a gateway to the LAN
#this is the LAN interface of the host running OpenVPN server
export SERVER_NET=192.168.86.24/24   

#modify this value to match the address of the remote cloud client's LAN interface
export CLOUD_NET_GW=10.150.0.42

#interface names in the OpenVPN LAN server
export SERVER_INT_IF=enp2s0f1 #TO_LAN
export SERVER_EXT_IF=openvpn_server #TO_VPN

#enable ip forwarding on this host
#this should have been done already on the GUI to get things working
#echo 1 > /proc/sys/net/ipv4/ip_forward

#enable traffic from openvpn to LAN: only TCP on ports 80 and 443
#iptables -A FORWARD -i $SERVER_EXT_IF -o $SERVER_INT_IF -p tcp --syn --dport 80 -m conntrack --ctstate NEW -j ACCEPT
#iptables -A FORWARD -i $SERVER_EXT_IF -o $SERVER_INT_IF -p tcp --syn --dport 443 -m conntrack --ctstate NEW -j ACCEPT

#enable traffic from openvpn to LAN: ALL TRAFFIC (not only TCP on ports 80 and 443)
iptables -A FORWARD -i $SERVER_EXT_IF -o $SERVER_INT_IF --syn -m conntrack --ctstate NEW -j ACCEPT


#enable returning traffic from established connections on both directions
iptables -A FORWARD -i $SERVER_EXT_IF -o $SERVER_INT_IF -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i $SERVER_INT_IF -o $SERVER_EXT_IF -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#DNAT: swap destination address on traffic from VPN to/from LAN
iptables -t nat -A PREROUTING -i $SERVER_EXT_IF -p tcp --dport 80 -j DNAT  --to-destination $SERVER_NET
iptables -t nat -A PREROUTING -i $SERVER_EXT_IF -p tcp --dport 443 -j DNAT  --to-destination $SERVER_NET


#SNAT: swap source address on traffic from CLOUD to/from onprem
iptables -t nat -A POSTROUTING -o $SERVER_INT_IF -j MASQUERADE

#Add the below route to reach the on-prem instance.
ip route add $SERVER_NET via $CLIENT_NET_GW dev $SERVER_INT_IF



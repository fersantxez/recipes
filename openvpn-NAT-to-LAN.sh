#!/bin/bash

#Script to NAT to/from an OpenVPN Server running in local LAN (e.g. home network) we call SERVER_NET
# into an OpenVPN client running away (cloud) in a remote CLIENT_NET
#Objective: to have client/s in cloud appear as local nodes in server (home) network (NAT 1:1)
#This runs on the OPEN_SERVER that runs in the SERVER_NET (home net usually)

#
#  [CLIENT_NET]--(client_net_gw)(ovpn_client)--OVPNTUN--(ovpn_server)(server_net_gw)--[SERVER_NET]
#      ^^                      ^^^                ^^                ^^^                   ^^^
#   usually_VPC       usually_VM_in_Cloud      internet     usually_server_home       home_net(192.168...)
#

#ISSUE: 
#  - Server network hosts (behind openvpn server) don't know how to reach the CLIENT_GW or the CLIENT_NET
#  - Client and client network hosts (behind client) don't know how to reach the CLIENT_GW or the CLIENT_NET


#modify this value to match the address to be reached in home network as a gateway to the LAN
#this is the LAN interface of the host running OpenVPN server
export SERVER_NET_GW=192.168.86.24   
export SERVER_NET=192.168.86.0/24   

#modify this value to match the address of the remote cloud client's LAN interface
export CLIENT_NET_GW=10.150.0.42
export CLIENT_NET=10.150.0.0/16

#interface names in the OpenVPN LAN server
export SERVER_INT_IF=enp2s0f1 #TO_LAN
export SERVER_EXT_IF=openvpn_server #TO_VPN

#enable ip forwarding on this host
#this should have been done already on the GUI to get things working
#echo 1 > /proc/sys/net/ipv4/ip_forward

### Enable FORWARD between interfaces (with connection tracking to allow returning connections)
#enable incoming traffic from openvpn to LAN: only TCP on ports 80 and 443
#iptables -A FORWARD -i $SERVER_EXT_IF -o $SERVER_INT_IF -p tcp --syn --dport 80 -m conntrack --ctstate NEW -j ACCEPT
#iptables -A FORWARD -i $SERVER_EXT_IF -o $SERVER_INT_IF -p tcp --syn --dport 443 -m conntrack --ctstate NEW -j ACCEPT


#### Enable SNAT: for traffic outgoing to the VPN from the home network, 
####              masquerade changing the source address to (OVPN_SERVER) address so that responses can be routed back
#swap source address on traffic from CLIENT_NET to/from onprem
iptables -t nat -A POSTROUTING -o $SERVER_INT_IF -j MASQUERADE

#enable incoming traffic from openvpn to LAN: all traffic 
iptables -A FORWARD -i $SERVER_EXT_IF -o $SERVER_INT_IF --syn -m conntrack --ctstate NEW -j ACCEPT

### Enable DNAT: for traffic incoming from OVPN to SERVER_NET
###              swap destionation address to SERNER_NET_GW -- so that it's all process by SERVER?
#swap destination address on traffic from VPN to/from LAN: only on ports 44 and 443
#iptables -t nat -A PREROUTING -i $SERVER_EXT_IF -p tcp --dport 80 -j DNAT --to-destination $SERVER_NET_GW
#iptables -t nat -A PREROUTING -i $SERVER_EXT_IF -p tcp --dport 443 -j DNAT --to-destination $SERVER_NET_GW

#swap destination address on traffic from VPN to/from LAN: all traffic
iptables -t nat -A PREROUTING -i $SERVER_EXT_IF -j DNAT --to-destination $SERVER_NET_GW    ##-p tcp --dport 80 

#enable returning traffic from established connections on both directions
iptables -A FORWARD -i $SERVER_EXT_IF -o $SERVER_INT_IF -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i $SERVER_INT_IF -o $SERVER_EXT_IF -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#Add the below route to SERVER_NET in order for the CLIENT to reach the hosts on prem.
ip route add $SERVER_NET via $CLIENT_NET_GW dev $SERVER_INT_IF



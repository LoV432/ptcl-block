#!/bin/ash

# An OpenWRT script that fetches IPs/Domains from multiple sources and adds them to a PBR rules.
# To use this script, you need to setup a VPN connection and install the PBR package on your OpenWRT.
# Then create 2 rules named "pbr_ips" amd "pbr_domains" in PBR which is routed through the VPN.
# The script requires the following dependencies:
# - whois
# - curl

# Guides on how to setup VPN:
# - https://openwrt.org/docs/guide-user/services/vpn/wireguard/client
# - https://openwrt.org/docs/guide-user/services/vpn/openvpn/client-luci

# You can read more about PBR at https://docs.openwrt.melmac.net/pbr/
# PS: You should try your best to use https://docs.openwrt.melmac.net/pbr/#UseDNSMASQnftsetsSupport


if ! [ -x "$(command -v whois)" ] || ! [ -x "$(command -v curl)" ]; then
    echo "Error: whois or curl is not installed."
    exit 1
fi

lov432_domains=""   # Anything from https://github.com/LoV432/pta-block/tree/master/domains
v2fly_domains=""    # Anything from https://github.com/v2fly/domain-list-community/tree/master/data
domains=""          # Add any hardcoded domains here
ips=""              # Add any hardcoded IPs here

# Prase domains from lov432
for lov432_domain in $lov432_domains; do
        fetched_domains=$(curl -s "https://raw.githubusercontent.com/LoV432/pta-block/master/domains/$lov432_domain" | tr '\n' ' ')
        for fetched_domain in $fetched_domains; do
            if [[ $fetched_domain == "as:"* ]]; then
                asn_ips=$(whois -h whois.pwhois.org "type=json routeview source-as=${fetched_domain#as:}" | grep -o '"Prefix":"[^"]*' | awk -F ':"' '{print $2}' | tr -d '\' | tr '\n' ' ')
                ips="$ips $asn_ips"
            elif [[ $fetched_domain == "ip:"* ]]; then
                ips="$ips ${fetched_domain#ip:}"
            elif [[ $fetched_domain == "#"* ]]; then
                # Ignore comments
                continue
            else
                domains="$domains $fetched_domain"
            fi
        done
done

# Parse domains from v2fly
for fetch_domain in $v2fly_domains; do
        fetch_domain=$(curl -s "https://raw.githubusercontent.com/v2fly/domain-list-community/master/data/$fetch_domain" | tr '\n' ' ')
        domains="$domains $fetch_domain"
done

rulenum=$(uci show pbr | grep 'pbr_ips' | sed 's/.*\@//;s/\.name.*//'); uci set pbr.@"$rulenum".dest_addr="$ips"
rulenum=$(uci show pbr | grep 'pbr_domains' | sed 's/.*\@//;s/\.name.*//'); uci set pbr.@"$rulenum".dest_addr="$domains"
uci commit pbr
service pbr restart


echo
echo "List Updated"
echo

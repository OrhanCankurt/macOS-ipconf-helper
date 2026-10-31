# macOS IP configuration: ipconf [-all | /all] [-4 | /4 | -v4 | /v4 | -ipv4 | /ipv4 | -6 | /6 | -v6 | /v6 | -ipv6 | /ipv6]

_ip_field() {
    printf '  %-31s : %s\n' "$1" "$2"
}

_ip_usage() {
    cat <<'USAGE'
Usage: ipconf [FAMILY] [DETAILS]

Show network adapter configuration (IPv4 by default).

Family selectors (choose at most one):
  -4, /4, -v4, /v4, -ipv4, /ipv4   Show IPv4 only (default)
  -6, /6, -v6, /v6, -ipv6, /ipv6   Show IPv6 only

Details:
  -all, /all                         Show additional network and DHCP details
  -help, /help                       Show this help

Examples:
  ipconf
  ipconf -4
  ipconf /ipv6 /all
USAGE
}

_ip_header() {
    local iface="$1" name mac

    name=$(networksetup -listallhardwareports 2>/dev/null |
        awk -v device="$iface" '
            /^Hardware Port: / { port = substr($0, 16) }
            /^Device: / && $2 == device { print port; exit }
        ')
    mac=$(ifconfig "$iface" 2>/dev/null |
        awk '/^[[:space:]]*ether / {print $2; exit}')

    [[ -n "$name" ]] || name="Network Adapter"
    if [[ -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
        printf '\033[1m%s (%s)\033[0m\n' "$name" "$iface"
    else
        printf '%s (%s)\n' "$name" "$iface"
    fi
    printf '  ------------------------------------------\n'
    [[ -n "$mac" ]] && _ip_field "MAC Address" "$mac"
    return 0
}

_ip_summary_value() {
    awk -v key="$1" '
        $1 == key && $2 == ":" {
            sub(/^[^:]*:[[:space:]]*/, "")
            print
            exit
        }
    '
}

_ip_lease_date() {
    LC_ALL=C date -j -f '%m/%d/%Y %H:%M:%S' "$1" '+%d.%m.%Y %H:%M:%S'
}

_ip6_type() {
    local addr="${1%%\%*}"
    addr=$(printf '%s' "$addr" | tr '[:upper:]' '[:lower:]')

    case "$addr" in
        ::|0:0:0:0:0:0:0:0)
            printf 'Unspecified'
            ;;
        ::1|0:0:0:0:0:0:0:1)
            printf 'Loopback'
            ;;
        fe[89ab]*)
            printf 'Link-Local (LLA)'
            ;;
        fc*|fd*)
            printf 'Unique Local (ULA)'
            ;;
        2*|3*)
            printf 'Global Unicast (GUA)'
            ;;
        *)
            printf 'Other'
            ;;
    esac
}

function ipconf {
    local showall=0 show4=1 show6=0 family= arg
    local gateway suffix dns dns4 dns6 dns_config iface config ipv4 ipv6 ipv6_usable
    local ip maskhex addr prefix ipv6_type ipv6_label
    local masknum mask cidr bits ipnum network broadcast
    local network_ip broadcast_ip dhcp dhcp_server lease_hex
    local summary lease_start lease_end

    # Parse options in any order; permit combining a family selector with "all".
    while [[ $# -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            -help|/help)
                _ip_usage
                return 0
                ;;
            -all|/all)
                showall=1
                ;;
            -4|/4|-v4|/v4|-ipv4|/ipv4)
                if [[ "$family" == "6" ]]; then
                    printf 'Error: choose either IPv4 or IPv6, not both.\n' >&2
                    return 2
                fi
                family=4
                ;;
            -6|/6|-v6|/v6|-ipv6|/ipv6)
                if [[ "$family" == "4" ]]; then
                    printf 'Error: choose either IPv4 or IPv6, not both.\n' >&2
                    return 2
                fi
                family=6
                ;;
            *)
                printf 'Error: invalid argument: %s\nUsage: ipconf [-all | /all] [-4 | /4 | -v4 | /v4 | -ipv4 | /ipv4 | -6 | /6 | -v6 | /v6 | -ipv6 | /ipv6]\n' "$arg" >&2
                return 2
                ;;
        esac
        shift
    done
    family="${family:-4}"
    if [[ "$family" == "6" ]]; then
        show4=0
        show6=1
    fi

    # These settings are system-wide, so collect them once before scanning adapters.
    gateway=$(route -n get default 2>/dev/null |
        awk '/gateway:/ {print $2; exit}')
    dns_config=$(scutil --dns 2>/dev/null)
    suffix=$(printf '%s\n' "$dns_config" |
        awk '/search domain\[0\]/ {print $NF; exit}')
    dns4=$(printf '%s\n' "$dns_config" |
        awk '/nameserver\[[0-9]+\]/ && $3 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print $3}' |
        sort -u | paste -sd ',' -)
    dns6=$(printf '%s\n' "$dns_config" |
        awk '/nameserver\[[0-9]+\]/ && $3 ~ /:/ {print $3}' |
        sort -u | paste -sd ',' -)
    if [[ "$family" == "4" ]]; then
        dns="$dns4"
    else
        dns="$dns6"
    fi

    while IFS= read -r iface; do
        # Skip interfaces that have only link-local IPv6 addresses, common on macOS virtual adapters.
        config=$(ifconfig "$iface") || return $?
        ipv4=$(printf '%s\n' "$config" |
            awk '/inet / && $2 != "127.0.0.1" {print $2, $4}')
        ipv6=$(printf '%s\n' "$config" |
            awk '/inet6 / {
                for (i = 3; i < NF; i++) {
                    if ($i == "prefixlen") {
                        print $2, $(i + 1)
                        break
                    }
                }
            }')

        # Loopback and link-local-only adapters are noisy; keep link-local addresses on active adapters.
        ipv6_usable=
        while read -r addr prefix; do
            [[ -n "$addr" ]] || continue
            ipv6_type=$(_ip6_type "$addr")
            if [[ "$ipv6_type" != "Loopback" &&
                  "$ipv6_type" != "Link-Local (LLA)" ]]; then
                ipv6_usable=1
            fi
        done <<< "$ipv6"
        [[ "$show4" -eq 1 && -n "$ipv4" ||
           "$show6" -eq 1 && -n "$ipv6_usable" ]] || continue

        _ip_header "$iface"
        if [[ "$show4" -eq 1 ]]; then
            while read -r ip maskhex; do
                [[ -n "$ip" ]] || continue
                masknum=$((maskhex))
                printf -v mask '%d.%d.%d.%d' \
                    $(((masknum >> 24) & 255)) \
                    $(((masknum >> 16) & 255)) \
                    $(((masknum >> 8) & 255)) \
                    $((masknum & 255))

                # Count set mask bits to convert the dotted subnet mask to CIDR notation.
                cidr=0
                bits=$((masknum & 0xffffffff))
                while ((bits)); do
                    cidr=$((cidr + (bits & 1)))
                    bits=$((bits >> 1))
                done

                _ip_field "IPv4 Address" "$ip/$cidr"
                _ip_field "Subnet Mask" "$mask"

                if [[ "$showall" -eq 1 ]]; then
                    # Apply the subnet mask to derive the network and broadcast addresses.
                    ipnum=$(IFS=. read -r a b c d <<< "$ip"
                        printf '%s' "$((10#$a << 24 |
                            10#$b << 16 | 10#$c << 8 | 10#$d))")
                    network=$((ipnum & masknum))
                    broadcast=$((network | (0xffffffff ^ masknum)))

                    printf -v network_ip '%d.%d.%d.%d' \
                        $(((network >> 24) & 255)) \
                        $(((network >> 16) & 255)) \
                        $(((network >> 8) & 255)) \
                        $((network & 255))
                    printf -v broadcast_ip '%d.%d.%d.%d' \
                        $(((broadcast >> 24) & 255)) \
                        $(((broadcast >> 16) & 255)) \
                        $(((broadcast >> 8) & 255)) \
                        $((broadcast & 255))

                    _ip_field "Network Address" "$network_ip/$cidr"
                    _ip_field "Broadcast Address" "$broadcast_ip"
                fi
            done <<< "$ipv4"
        fi

        if [[ "$show6" -eq 1 ]]; then
          while read -r addr prefix; do
            if [[ -n "$addr" ]]; then
                ipv6_type=$(_ip6_type "$addr")
                [[ "$ipv6_type" == "Loopback" ]] && continue
                ipv6_label=${ipv6_type% (*)}
                _ip_field "IPv6 $ipv6_label Address" "$addr/$prefix"
            fi
          done <<< "$ipv6"
        fi

        [[ "$show4" -eq 1 && -n "$ipv4" ]] &&
            _ip_field "Default Gateway" "${gateway:-N/A}"
        [[ -n "$suffix" ]] && _ip_field "DNS Suffix" "$suffix"

        if [[ "$showall" -eq 1 ]]; then
            [[ -n "$dns" ]] && _ip_field "DNS Servers" "$dns"

            if [[ "$show4" -eq 1 && -n "$ipv4" ]]; then
                # macOS exposes DHCP lease details through ipconfig's packet and summary.
                dhcp=$(ipconfig getpacket "$iface" 2>/dev/null)
                dhcp_server=$(printf '%s\n' "$dhcp" |
                    awk -F': ' '/server_identifier/ {print $2; exit}')
                lease_hex=$(printf '%s\n' "$dhcp" |
                    awk -F': ' '/lease_time/ {print $2; exit}')

                printf '\n  DHCP\n'
                if [[ -n "$lease_hex" ]]; then
                    _ip_field "Status" "Enabled"
                    [[ -n "$dhcp_server" ]] &&
                        _ip_field "Server" "$dhcp_server"
                    _ip_field "Lease Duration" "$((lease_hex)) seconds"

                    summary=$(ipconfig getsummary "$iface") || return $?
                    lease_start=$(printf '%s\n' "$summary" |
                        _ip_summary_value LeaseStartTime)
                    lease_end=$(printf '%s\n' "$summary" |
                        _ip_summary_value LeaseExpirationTime)

                    # Convert macOS's month-first dates to the requested day-first format.
                    if [[ -n "$lease_start" ]]; then
                        lease_start=$(_ip_lease_date "$lease_start") || return $?
                        _ip_field "Lease Start" "$lease_start"
                    fi
                    if [[ -n "$lease_end" ]]; then
                        lease_end=$(_ip_lease_date "$lease_end") || return $?
                        _ip_field "Lease End" "$lease_end"
                    fi
                else
                    _ip_field "Status" "No DHCP lease reported"
                fi
            fi
        fi
        printf '\n'
    done < <(ifconfig -l | tr ' ' '\n' | awk 'NF')
}

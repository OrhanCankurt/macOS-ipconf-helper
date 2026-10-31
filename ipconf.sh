# macOS IP configuration: ipconf, ipconf -all, ipconf /all

_ip_validate_args() {
    local command="$1"
    shift

    if [[ $# -eq 0 ]]; then
        return 0
    fi
    if [[ $# -eq 1 && ( "$1" == "-all" || "$1" == "/all" ) ]]; then
        return 0
    fi

    printf 'Error: invalid arguments. Usage: %s [-all | /all]\n' "$command" >&2
    return 2
}

_ip_field() {
    printf '  %-19s : %s\n' "$1" "$2"
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

function ipconf {
    # Accept only no option or the supported "show all" options.
    _ip_validate_args ipconf "$@" || return $?

    local showall=0
    local gateway suffix dns iface config ipv4 ipv6 ip maskhex addr prefix
    local masknum mask cidr bits ipnum network broadcast
    local network_ip broadcast_ip dhcp dhcp_server lease_hex
    local summary lease_start lease_end
    [[ $# -eq 1 ]] && showall=1

    # These settings are system-wide, so collect them once before scanning adapters.
    gateway=$(route -n get default 2>/dev/null |
        awk '/gateway:/ {print $2; exit}')
    dns=$(scutil --dns 2>/dev/null)
    suffix=$(printf '%s\n' "$dns" |
        awk '/search domain\[0\]/ {print $NF; exit}')
    dns=$(printf '%s\n' "$dns" |
        awk '/nameserver\[[0-9]+\]/ {print $3}' |
        sort -u | paste -sd ',' -)

    while IFS= read -r iface; do
        # Read each adapter once, then collect its non-loopback IPv4 and global IPv6 addresses.
        config=$(ifconfig "$iface") || return $?
        ipv4=$(printf '%s\n' "$config" |
            awk '/inet / && $2 != "127.0.0.1" {print $2, $4}')
        ipv6=$(printf '%s\n' "$config" |
            awk '/inet6 / && $2 !~ /^fe80/ && $2 != "::1" {
                for (i = 3; i < NF; i++) {
                    if ($i == "prefixlen") {
                        print $2, $(i + 1)
                        break
                    }
                }
            }')
        [[ -n "$ipv4" || -n "$ipv6" ]] || continue

        _ip_header "$iface"
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

        while read -r addr prefix; do
            [[ -n "$addr" ]] && _ip_field "IPv6 Address" "$addr/$prefix"
        done <<< "$ipv6"

        [[ -n "$ipv4" ]] && _ip_field "Default Gateway" "${gateway:-N/A}"
        [[ -n "$suffix" ]] && _ip_field "DNS Suffix" "$suffix"

        if [[ "$showall" -eq 1 ]]; then
            [[ -n "$dns" ]] && _ip_field "DNS Servers" "$dns"

            if [[ -n "$ipv4" ]]; then
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

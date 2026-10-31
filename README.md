# macOS `ipconf` helper

`ipconf` displays IPv4 configuration by default. Select IPv6 explicitly
with `-6` or `/6`. It can also show additional network and DHCP details.

## Requirements

- macOS
- Bash or Zsh
- The built-in `ifconfig`, `networksetup`, `route`, `scutil`, and `ipconfig`
  commands

## Installation

To make `ipconf` available in every Zsh terminal, copy `ip-helpers.sh` to a
stable location, then add it to `~/.zshrc`. Run these commands from the
directory containing `ip-helpers.sh`:

```zsh
mkdir -p "$HOME/.local/share/ipconf"
cp ./ip-helpers.sh "$HOME/.local/share/ipconf/ip-helpers.sh"

grep -Fqx 'source "$HOME/.local/share/ipconf/ip-helpers.sh"' "$HOME/.zshrc" 2>/dev/null ||
  printf '\n%s\n' 'source "$HOME/.local/share/ipconf/ip-helpers.sh"' >> "$HOME/.zshrc"

source "$HOME/.zshrc"
```

The `grep` check prevents adding the source line more than once. Open a new
terminal after installation, or run `source ~/.zshrc` to reload it. To install
for Bash instead, add the same `source "$HOME/.local/share/ipconf/ip-helpers.sh"`
line to `~/.bash_profile`.

## Usage

**IPv4 is the default:** `ipconf`, `ipconf -all`, and `ipconf /all` show
only IPv4 configuration and IPv4 DNS servers. IPv6 requires an explicit
selector, such as `ipconf /6` or `ipconf /6 /all`.

```text
ipconf
ipconf -help
ipconf /help
ipconf -all
ipconf /all
ipconf -4       # /4, -v4, /v4, -ipv4, /ipv4
ipconf -6       # /6, -v6, /v6, -ipv6, /ipv6
ipconf /4 /all
ipconf /6 /all
```

Run `ipconf -help` or `ipconf /help` to display usage:

```text
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
```

`ipconf` shows each adapter's name, interface identifier, MAC address, IPv4
addresses, subnet masks, default gateway, and DNS suffix when available.

Use `-4`, `-v4`, or `-ipv4` (or their `/4`, `/v4`, `/ipv4` forms) to show
only IPv4 details. Use `-6`, `-v6`, or `-ipv6` (or `/6`, `/v6`, `/ipv6`) to
show only IPv6 details. Add `-all` or `/all` to either selector for additional
details, for example `ipconf /ipv6 /all`. If no family selector is given,
only IPv4 is shown, including with `ipconf /all`. Specifying both IPv4 and
IPv6 selectors is an error.

IPv6 addresses are labeled as Link-Local (LLA, `fe80::/10`), Unique Local
(ULA, `fc00::/7`), Global Unicast (GUA, `2000::/3`), Unspecified (`::/128`),
or Other for addresses outside those ranges. The type is part of the address
field label, for example `IPv6 Link-Local Address`. Loopback (`::1/128`)
addresses are omitted, and interfaces with only link-local IPv6 addresses are
hidden to avoid listing the many auxiliary interfaces macOS creates.
Link-local addresses are still shown on adapters that also have IPv4 or
another IPv6 address.

The `-all` and `/all` options add network and broadcast addresses, DNS
servers, and DHCP status and lease details when available. IPv4 subnet masks
are also shown without these options.
For IPv6-only output, the extra details include DNS servers; IPv4 subnet and
DHCP details are only shown when IPv4 is selected. Lease start and end times
use the `DD.MM.YYYY HH:MM:SS` format. DNS server addresses are filtered to
the selected IP version, including the default IPv4 mode.

Unsupported arguments, such as `ipconf all`, print an error and return a
nonzero status.

## Example output

The regular command shows the adapter and its IPv4 addresses:

```text
Wi-Fi (en0)
  ------------------------------------------
  MAC Address                     : 02:00:00:00:00:01
  IPv4 Address                    : 192.0.2.42/24
  Subnet Mask                     : 255.255.255.0
  Default Gateway                 : 192.0.2.1
  DNS Suffix                      : example.invalid
```

With `/all` (or `-all`), it includes network, DNS, and DHCP details:

```text
Wi-Fi (en0)
  ------------------------------------------
  MAC Address                     : 02:00:00:00:00:01
  IPv4 Address                    : 192.0.2.42/24
  Subnet Mask                     : 255.255.255.0
  Network Address                 : 192.0.2.0/24
  Broadcast Address               : 192.0.2.255
  Default Gateway                 : 192.0.2.1
  DNS Suffix                      : example.invalid
  DNS Servers                     : 192.0.2.1

  DHCP
  Status                          : Enabled
  Server                          : 192.0.2.1
  Lease Duration                  : 86400 seconds
  Lease Start                     : 01.01.2025 12:00:00
  Lease End                       : 02.01.2025 12:00:00
```

Use `ipconf /6 /all` to show IPv6 explicitly:

```text
Wi-Fi (en0)
  ------------------------------------------
  MAC Address                     : 02:00:00:00:00:01
  IPv6 Link-Local Address         : fe80::1234%en0/64
  IPv6 Unique Local Address       : fd12:3456:789a::42/64
  IPv6 Global Unicast Address     : 2001:db8::42/64
  DNS Suffix                      : example.invalid
  DNS Servers                     : 2001:db8::53
```

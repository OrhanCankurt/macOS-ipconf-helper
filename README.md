# macOS `ipconf` helper

`ipconf` displays IPv4 and IPv6 configuration together for each network
adapter. It can also show additional network and DHCP details.

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

```text
ipconf
ipconf -all
ipconf /all
```

`ipconf` shows each adapter's name, interface identifier, MAC address, IPv4
and IPv6 addresses, default gateway (when IPv4 is configured), and DNS suffix
when available.

The `-all` and `/all` options also show subnet masks, network and broadcast
addresses, DNS servers, and DHCP status and lease details when available.
Lease start and end times use the `DD.MM.YYYY HH:MM:SS` format.

Any other arguments, such as `ipconf all`, print a usage error and return a
nonzero status.

## Example output

The regular command shows the adapter and its IPv4/IPv6 addresses:

```text
Wi-Fi (en0)
  ------------------------------------------
  MAC Address         : 02:00:00:00:00:01
  IPv4 Address        : 192.0.2.42/24
  Subnet Mask         : 255.255.255.0
  IPv6 Address        : 2001:db8::42/64
  Default Gateway     : 192.0.2.1
  DNS Suffix          : example.com
```

With `/all` (or `-all`), it includes network, DNS, and DHCP details:

```text
Wi-Fi (en0)
  ------------------------------------------
  MAC Address         : 02:00:00:00:00:01
  IPv4 Address        : 192.0.2.42/24
  Subnet Mask         : 255.255.255.0
  Network Address     : 192.0.2.0/24
  Broadcast Address   : 192.0.2.255
  IPv6 Address        : 2001:db8::42/64
  Default Gateway     : 192.0.2.1
  DNS Suffix          : example.com
  DNS Servers         : 192.0.2.1

  DHCP
  Status              : Enabled
  Server              : 192.0.2.1
  Lease Duration      : 86400 seconds
  Lease Start         : 01.01.2025 12:00:00
  Lease End           : 02.01.2025 12:00:00
```

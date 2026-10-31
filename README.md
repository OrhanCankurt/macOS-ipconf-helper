# macOS `ipconf` helper

`ipconf` displays IPv4 and IPv6 configuration together for each network
adapter. It can also show additional network and DHCP details.

## Requirements

- macOS
- Bash or Zsh
- The built-in `ifconfig`, `networksetup`, `route`, `scutil`, and `ipconfig`
  commands

## Installation

Save `ip-helpers.sh` somewhere in your home directory, then add this line to
your shell startup file:

```bash
source "$HOME/path/to/ip-helpers.sh"
```

For Bash, the startup file is usually `~/.bash_profile`. For Zsh, use
`~/.zshrc`. Reload the startup file or open a new terminal to use the function.

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

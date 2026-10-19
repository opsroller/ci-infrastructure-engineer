# Run the PXE server on a NixOS host

Use this guide to let UEFI machines on a LAN network-boot Fedora CoreOS
from a NixOS host. The LAN must already have a DHCP server.

1. Add the flake as an input to the host's system flake and import the
   module:

   ```nix
   inputs.ci-infrastructure.url = "github:opsroller/ci-infrastructure-engineer";
   # in the host's modules list:
   ci-infrastructure.nixosModules.pxe-coreos
   ```

2. Configure it for the host's LAN interface:

   ```nix
   services.pxe-coreos = {
     enable = true;
     interface = "eno1";
     butane = {
       variant = "fcos";
       version = "1.6.0";
       passwd.users = [
         { name = "core"; ssh_authorized_keys = [ "ssh-ed25519 AAAA..." ]; }
       ];
     };
   };
   ```

   The subnet and this host's address are found at boot time, so the
   host may take its address from DHCP.

3. Rebuild and switch:

   ```
   sudo nixos-rebuild switch
   ```

4. Check that both services are running:

   ```
   systemctl status pxe-coreos-dnsmasq pxe-coreos-http
   ```

5. In each machine's UEFI setup, enable network boot (PXE over IPv4)
   and turn off Secure Boot. Then boot it from the network. Watch the
   requests arrive:

   ```
   journalctl -fu pxe-coreos-dnsmasq
   ```

By default the machines run Fedora CoreOS live from RAM and no disk
is changed. To install to a disk instead, set `installDevice`. See
[the options](../reference/module-options.md).

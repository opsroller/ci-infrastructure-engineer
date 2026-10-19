# Run the PXE server as a libvirt guest

Use this guide to serve network boot on a LAN from a libvirt host
without changing the host's own system config. You need access to
`qemu:///system`, for example membership of the `libvirtd` group, and
a LAN that already has a DHCP server.

The server runs as a small NixOS guest attached straight to a host
interface through macvtap. It gets its address from the LAN's DHCP
server, and booting machines find it from its proxy-DHCP answer. Its
disk is a volume in a libvirt storage pool.

1. Write the Butane config for the machines that will boot, as a Nix
   file. For example, `butane.nix`:

   ```nix
   {
     variant = "fcos";
     version = "1.6.0";
     passwd.users = [
       { name = "core"; ssh_authorized_keys = [ "ssh-ed25519 AAAA..." ]; }
     ];
   }
   ```

2. Start the server on the host's LAN interface:

   ```
   scripts/pxe-server-vm up eno1 butane.nix
   ```

   This builds the guest image, uploads it as `pxe-server.qcow2` into the
   `default` pool, defines `pxe-server` with autostart, and starts it.
   To use another pool, set `POOL=<name>`.

3. Check that it took a LAN address and that proxy-DHCP is up:

   ```
   virsh -c qemu:///system console pxe-server
   ```

   Look for `dnsmasq-dhcp: ... proxy on subnet ...`. Leave the console
   with `Ctrl+]`.

4. In each machine's UEFI setup, turn off Secure Boot and enable PXE
   over IPv4, then boot it from the network.

The host cannot reach the guest over macvtap, but the rest of the LAN
can. To change the Butane config, run step 2 again. To remove the
server and its volume:

```
scripts/pxe-server-vm down
```

# CI infrastructure engineer

Infrastructure for running CI on machines and virtual machines you own.
The first piece is a network boot server: a NixOS module that boots
UEFI machines on an existing LAN into Fedora CoreOS over PXE, without
taking over the LAN's DHCP.

- Proxy-DHCP and TFTP (dnsmasq) answer only network-boot requests.
  The LAN's DHCP server keeps handing out addresses.
- A custom iPXE binary fetches its boot script over HTTP.
- The Fedora CoreOS live kernel, initramfs and rootfs are pinned by
  SHA-256 and held in the Nix store.
- An Ignition config is compiled from Butane at build time.

Nothing is kept in a project folder. Images live in the Nix store, and
VM storage is left to libvirt.

## Documentation

- Tutorial: [Network-boot Fedora CoreOS in a test VM](docs/tutorials/boot-test.md)
- How-to: [Run the PXE server as a libvirt guest](docs/how-to/run-pxe-server-vm.md),
  [Run the PXE server on a NixOS host](docs/how-to/deploy-pxe-server.md),
  [Update the pinned Fedora CoreOS release](docs/how-to/update-fcos-pin.md)
- Reference: [`services.pxe-coreos` options](docs/reference/module-options.md)
- Explanation: [How the network boot works](docs/explanation/network-boot.md)

## License

GPL-2.0-or-later. See [LICENSE](LICENSE).

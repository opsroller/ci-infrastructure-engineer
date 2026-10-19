# `services.pxe-coreos` options

NixOS module `nixosModules.pxe-coreos` (also `nixosModules.default`).

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `enable` | bool | `false` | Run the proxy-DHCP, TFTP and HTTP services. |
| `interface` | string | none | Interface on the network whose machines boot from this host. |
| `network` | null or string | `null` | Network address of that interface's subnet, such as `192.168.1.0`. `null` uses the interface's subnet when the service starts. |
| `serverAddress` | null or string | `null` | This host's address, written into the boot URLs. `null` lets iPXE read it from the proxy-DHCP answer. |
| `httpPort` | port | `8080` | Port of the HTTP server. |
| `butane` | attrs | none | Butane config, `fcos` variant, as Nix. It is compiled with `butane --strict` at build time. |
| `installDevice` | null or string | `null` | `null` boots live from RAM. A device path, such as `/dev/nvme0n1`, installs to that disk and erases it. |
| `kernelArgs` | list of strings | `[ ]` | Extra kernel arguments for the booted machines. |
| `openFirewall` | bool | `true` | Opens UDP 67, 69 and 4011 and TCP `httpPort` on `interface`. |

## Services

| Unit | Program | Listens on |
| --- | --- | --- |
| `pxe-coreos-dnsmasq` | dnsmasq, proxy-DHCP and TFTP, no DNS | UDP 67, 69 and 4011 on `interface` |
| `pxe-coreos-http` | darkhttpd, runs as a dynamic user | TCP `httpPort` |

## Served files

| Path | Served over | Content |
| --- | --- | --- |
| `ipxe.efi` | TFTP | iPXE with an embedded script that chains `boot.ipxe` |
| `boot.ipxe` | HTTP | Kernel arguments and image URLs |
| `kernel`, `initramfs.img`, `rootfs.img` | HTTP | Fedora CoreOS live images from `nix/fcos-pin.json` |
| `config.ign` | HTTP | Ignition config compiled from `butane` |

## Flake outputs

| Output | Purpose |
| --- | --- |
| `packages.x86_64-linux.default` | Tools: butane, curl, jq, libvirt, OVMF, gh |
| `packages.x86_64-linux.pxe-server-image` | qcow2 image of the PXE server guest (`nix/server-vm.nix`). Override `butane` and `kernelArgs` with `.override`. |
| `packages.x86_64-linux.pxe-server-test-image` | The server image that `scripts/test-pxe-libvirt` boots |
| `packages.x86_64-linux.pxe-test` | TFTP and HTTP trees used by `scripts/test-pxe-boot` |
| `checks.x86_64-linux.dnsmasq-config` | Evaluates the module and runs `dnsmasq --test` on its config |

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/test-pxe-boot [timeout]` | Boots a diskless UEFI QEMU guest through the full chain. Exits 0 on success. |
| `scripts/test-pxe-libvirt [timeout]` | Boots the server guest and a diskless UEFI client on an isolated libvirt network, whose own DHCP server hands out addresses. Exits 0 when the client boots. |
| `scripts/pxe-server-vm up\|down\|status` | Runs the server as a persistent libvirt guest on a host interface. |
| `scripts/update-fcos-pin [stream] [arch]` | Prints a new pin for `nix/fcos-pin.json`. |

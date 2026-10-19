# Network-boot Fedora CoreOS in a test VM

In this tutorial you boot a diskless UEFI virtual machine into Fedora
CoreOS over the network, using the same boot chain a physical machine
uses. It takes about five minutes and needs no root access.

You need Nix with flakes and access to `/dev/kvm`.

1. Clone the repository and enter it:

   ```
   git clone https://github.com/opsroller/ci-infrastructure-engineer
   cd ci-infrastructure-engineer
   ```

2. Run the boot test:

   ```
   scripts/test-pxe-boot
   ```

   The first run downloads about 1 GB of Fedora CoreOS images into the
   Nix store. Then QEMU starts a UEFI guest with no disk. Its firmware
   gets `ipxe.efi` over TFTP from QEMU's built-in DHCP server. iPXE
   fetches the boot script, kernel and initramfs over HTTP from a server
   on your loopback. Fedora CoreOS then loads its rootfs and Ignition
   config from that same server.

3. Wait for the result. The Ignition config in the test enables a unit
   that prints a marker on the serial console, so a pass looks like:

   ```
   PXE-TEST-BOOTED 44.20260928.3.1
   PASS: UEFI PXE -> iPXE -> Fedora CoreOS live with Ignition in 28s
   ```

You booted Fedora CoreOS from the network and applied an Ignition
config, with nothing written to disk. To serve real machines on a LAN,
see [Run the PXE server on a NixOS host](../how-to/deploy-pxe-server.md).

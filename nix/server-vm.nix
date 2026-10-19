# SPDX-License-Identifier: GPL-2.0-or-later
#
# A small NixOS guest that runs the PXE server, for hosts where changing the
# host's own system config is not wanted. It takes its address from DHCP on
# its one interface (eth0); boot clients find it from the proxy-DHCP answer.
{
  network ? null,
  butane,
  kernelArgs ? [ ],
}:
{ lib, modulesPath, ... }:
{
  imports = [
    ./module.nix
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/profiles/minimal.nix"
  ];

  services.pxe-coreos = {
    enable = true;
    interface = "eth0";
    inherit network butane kernelArgs;
  };

  networking.hostName = "pxe-server";
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  boot.loader.grub.device = "/dev/vda";
  boot.kernelParams = [ "console=ttyS0,115200n8" ];
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };
  boot.growPartition = true;

  # Service logs on the serial console, so the host can watch it boot.
  services.journald.console = "/dev/ttyS0";

  documentation.enable = false;
  system.stateVersion = "26.05";
}

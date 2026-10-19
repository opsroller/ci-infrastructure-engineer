# SPDX-License-Identifier: GPL-2.0-or-later
#
# Builds everything a UEFI PXE boot of Fedora CoreOS needs, all in the Nix
# store: an iPXE binary for TFTP, and an HTTP tree with the boot script, the
# pinned live kernel, initramfs and rootfs, and the Ignition config.
{
  lib,
  pkgs,
  # Address the booting machines use to reach this server. null finds it at
  # boot time from the proxy-DHCP answer, so the server can take its own
  # address from DHCP.
  serverAddress ? null,
  httpPort ? 8080,
  # Fedora CoreOS artifacts pin, as written by scripts/update-fcos-pin.
  pin ? lib.importJSON ./fcos-pin.json,
  # Butane config (fcos variant) as a Nix attribute set.
  butane,
  # null boots the live system from RAM; a device path installs to that disk.
  installDevice ? null,
  kernelArgs ? [ ],
}:
let
  # iPXE expands ${pxe-server} in every command, kernel arguments included.
  base = "http://\${pxe-server}:${toString httpPort}";

  findServer =
    if serverAddress != null then
      "set pxe-server ${serverAddress}"
    else
      ''
        isset ''${proxydhcp/next-server} && set pxe-server ''${proxydhcp/next-server} || set pxe-server ''${next-server}
      '';

  fetch =
    name: a:
    pkgs.fetchurl {
      inherit (a) url sha256;
      name = "fedora-coreos-${pin.release}-${name}";
    };

  ignition =
    pkgs.runCommand "config.ign"
      {
        nativeBuildInputs = [ pkgs.butane ];
        butane = builtins.toJSON butane;
        passAsFile = [ "butane" ];
      }
      ''
        butane --strict --pretty < "$butanePath" > $out
      '';

  ignitionArgs =
    if installDevice == null then
      [
        "ignition.firstboot"
        "ignition.platform.id=metal"
        "ignition.config.url=${base}/config.ign"
      ]
    else
      [
        "coreos.inst.install_dev=${installDevice}"
        "coreos.inst.ignition_url=${base}/config.ign"
      ];

  args = lib.concatStringsSep " " (
    [
      "initrd=main"
      "coreos.live.rootfs_url=${base}/rootfs.img"
    ]
    ++ ignitionArgs
    ++ kernelArgs
  );

  bootScript = pkgs.writeText "boot.ipxe" ''
    #!ipxe
    echo Fedora CoreOS ${pin.release} (${pin.stream})
    kernel ${base}/kernel ${args}
    initrd --name main ${base}/initramfs.img
    boot
  '';

  # The embedded script replaces iPXE's autoboot, so a proxy-DHCP offer
  # pointing back at this same binary can never loop.
  ipxe = pkgs.ipxe.override {
    embedScript = pkgs.writeText "embed.ipxe" ''
      #!ipxe
      dhcp || goto failed
      ${findServer}
      echo Boot server ''${pxe-server}
      chain ${base}/boot.ipxe || goto failed
      :failed
      echo Network boot from ${base} failed; exiting to firmware
      sleep 10
      exit
    '';
  };
in
{
  inherit ignition bootScript pin;

  tftpRoot = pkgs.linkFarm "pxe-tftp-root" [
    {
      name = "ipxe.efi";
      path = "${ipxe}/ipxe.efi";
    }
  ];

  httpRoot = pkgs.linkFarm "pxe-http-root" [
    {
      name = "boot.ipxe";
      path = bootScript;
    }
    {
      name = "config.ign";
      path = ignition;
    }
    {
      name = "kernel";
      path = fetch "live-kernel" pin.kernel;
    }
    {
      name = "initramfs.img";
      path = fetch "live-initramfs.img" pin.initramfs;
    }
    {
      name = "rootfs.img";
      path = fetch "live-rootfs.img" pin.rootfs;
    }
  ];
}

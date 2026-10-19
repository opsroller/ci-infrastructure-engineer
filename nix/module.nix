# SPDX-License-Identifier: GPL-2.0-or-later
#
# NixOS module: a UEFI PXE boot server for Fedora CoreOS that runs beside the
# network's existing DHCP server (proxy-DHCP), so it never hands out addresses.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.pxe-coreos;

  tree = import ./pxe-tree.nix {
    inherit lib pkgs;
    inherit (cfg)
      serverAddress
      httpPort
      butane
      installDevice
      kernelArgs
      ;
  };

  # With no fixed network, serve the subnet the interface is on right now.
  startDnsmasq = pkgs.writeShellScript "pxe-coreos-dnsmasq" ''
    set -eu
    range=
    if ${lib.boolToString (cfg.network == null)}; then
      addr=$(${pkgs.iproute2}/bin/ip -4 -o addr show dev ${cfg.interface} | ${pkgs.gawk}/bin/awk '{ split($4, a, "/"); print a[1]; exit }')
      [ -n "$addr" ] || { echo "no IPv4 address on ${cfg.interface}" >&2; exit 1; }
      range=--dhcp-range=$addr,proxy
    fi
    exec ${pkgs.dnsmasq}/bin/dnsmasq --keep-in-foreground --log-facility=- --user=nobody --conf-file=${dnsmasqConf} $range
  '';

  dnsmasqConf = pkgs.writeText "pxe-coreos-dnsmasq.conf" ''
    # No DNS; proxy-DHCP and TFTP only.
    port=0
    interface=${cfg.interface}
    bind-dynamic
    # Proxy-DHCP keeps no leases, but dnsmasq still opens the file.
    dhcp-leasefile=/var/lib/pxe-coreos/dnsmasq.leases
    ${lib.optionalString (cfg.network != null) "dhcp-range=${cfg.network},proxy"}
    enable-tftp
    tftp-root=${tree.tftpRoot}
    pxe-prompt="Fedora CoreOS network boot",0
    pxe-service=x86-64_EFI,"Fedora CoreOS",ipxe.efi
    pxe-service=BC_EFI,"Fedora CoreOS",ipxe.efi
    log-dhcp
  '';
in
{
  options.services.pxe-coreos = {
    enable = lib.mkEnableOption "a proxy-DHCP UEFI PXE boot server for Fedora CoreOS";

    interface = lib.mkOption {
      type = lib.types.str;
      example = "eno1";
      description = "Interface on the network whose machines boot from this server.";
    };

    network = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.1.0";
      description = ''
        Network address of that interface's subnet. Proxy-DHCP answers
        boot requests there and leaves address assignment to the existing
        DHCP server. null (the default) uses the subnet of the interface's
        IPv4 address when the service starts.
      '';
    };

    serverAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.1.10";
      description = ''
        This host's address on that network, used in boot URLs. null (the
        default) lets iPXE take it from the proxy-DHCP answer, so this host
        may get its own address from DHCP.
      '';
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port of the HTTP server that serves images and configs.";
    };

    butane = lib.mkOption {
      type = lib.types.attrs;
      example = lib.literalExpression ''
        {
          variant = "fcos";
          version = "1.6.0";
          passwd.users = [ { name = "core"; ssh_authorized_keys = [ "ssh-ed25519 AAAA..." ]; } ];
        }
      '';
      description = ''
        Butane config (fcos variant) for the booted machines, as Nix. It is
        compiled to Ignition with `butane --strict` at build time.
      '';
    };

    installDevice = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/nvme0n1";
      description = ''
        null (the default) boots Fedora CoreOS live from RAM and changes no
        disk. A device path installs to that disk, erasing it; set the
        machines to boot from disk before network after the install.
      '';
    };

    kernelArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "console=ttyS0,115200n8" ];
      description = "Extra kernel arguments for the booted machines.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open DHCP, proxy-DHCP, TFTP and HTTP on the interface.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.pxe-coreos-dnsmasq = {
      description = "Proxy-DHCP and TFTP for Fedora CoreOS network boot";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStartPre = "${pkgs.dnsmasq}/bin/dnsmasq --test --conf-file=${dnsmasqConf}";
        ExecStart = startDnsmasq;
        StateDirectory = "pxe-coreos";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.services.pxe-coreos-http = {
      description = "HTTP server for Fedora CoreOS network boot";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${tree.httpRoot} --port ${toString cfg.httpPort} --no-listing";
        DynamicUser = true;
        Restart = "on-failure";
      };
    };

    networking.firewall.interfaces.${cfg.interface} = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [
        67
        69
        4011
      ];
      allowedTCPPorts = [ cfg.httpPort ];
    };
  };
}

# SPDX-License-Identifier: GPL-2.0-or-later
{
  description = "CI infrastructure: network-booted Fedora CoreOS machines";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      forAll = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
    in
    {
      nixosModules.pxe-coreos = ./nix/module.nix;
      nixosModules.default = self.nixosModules.pxe-coreos;

      # Evaluates the module on a minimal system and checks the generated
      # dnsmasq config with `dnsmasq --test`.
      checks = forAll (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          example = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.pxe-coreos
              {
                boot.loader.grub.enable = false;
                fileSystems."/" = {
                  device = "none";
                  fsType = "tmpfs";
                };
                system.stateVersion = "26.05";
                services.pxe-coreos = {
                  enable = true;
                  interface = "eth0";
                  network = "192.168.1.0";
                  serverAddress = "192.168.1.10";
                  butane = {
                    variant = "fcos";
                    version = "1.6.0";
                  };
                };
              }
            ];
          };
          dnsmasq = example.config.systemd.services.pxe-coreos-dnsmasq.serviceConfig;
        in
        {
          dnsmasq-config = pkgs.runCommand "dnsmasq-config-check" { } ''
            ${dnsmasq.ExecStartPre}
            touch $out
          '';
        }
      );

      packages = forAll (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            name = "ci-infrastructure-tools";
            dontUnpack = true;
            installPhase = "mkdir -p $out";
            nativeBuildInputs = with pkgs; [
              butane
              coreos-installer
              curl
              jq
              libvirt
              OVMF
              gh
            ];
          };

          # TFTP and HTTP trees for QEMU user-mode networking, used by
          # scripts/test-pxe-boot. The booted machine prints a marker on
          # its serial console once Ignition has applied the config.
          pxe-test =
            let
              tree = import ./nix/pxe-tree.nix {
                inherit (pkgs) lib;
                inherit pkgs;
                serverAddress = "10.0.2.2";
                kernelArgs = [ "console=ttyS0,115200n8" ];
                butane = {
                  variant = "fcos";
                  version = "1.6.0";
                  systemd.units = [
                    {
                      name = "pxe-test-marker.service";
                      enabled = true;
                      contents = ''
                        [Unit]
                        After=multi-user.target
                        [Service]
                        Type=oneshot
                        ExecStart=/bin/sh -c '. /etc/os-release; echo PXE-TEST-BOOTED $OSTREE_VERSION > /dev/ttyS0'
                        [Install]
                        WantedBy=multi-user.target
                      '';
                    }
                  ];
                };
              };
            in
            pkgs.linkFarm "pxe-test" [
              {
                name = "tftp";
                path = tree.tftpRoot;
              }
              {
                name = "http";
                path = tree.httpRoot;
              }
            ];
        }
      );
    };
}

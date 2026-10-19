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

          # qcow2 disk image of the PXE server guest (nix/server-vm.nix).
          serverImage =
            args:
            let
              vm = nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [ (import ./nix/server-vm.nix args) ];
              };
            in
            import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
              inherit pkgs;
              inherit (pkgs) lib;
              inherit (vm) config;
              format = "qcow2";
              diskSize = "auto";
              additionalSpace = "512M";
              # The guest is rebuilt, never updated in place: no nixpkgs copy.
              copyChannel = false;
              # The helper VM that fills the disk defaults to 1 GiB of RAM.
              memSize = 8192;
            };

          # Test clients run a unit that prints a marker on the serial
          # console once Ignition has applied the config.
          markerButane = {
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
        in
        {
          # Boot clients get Fedora CoreOS live with no users and no keys;
          # override butane for real use (docs/how-to/run-pxe-server-vm.md).
          pxe-server-image = pkgs.lib.makeOverridable serverImage {
            butane = {
              variant = "fcos";
              version = "1.6.0";
            };
          };

          default = pkgs.stdenvNoCC.mkDerivation {
            name = "ci-infrastructure-tools";
            dontUnpack = true;
            installPhase = "mkdir -p $out";
            nativeBuildInputs = with pkgs; [
              butane
              curl
              jq
              libvirt
              OVMF
              gh
            ];
          };

          # The server image the libvirt test boots, serving markerButane.
          pxe-server-test-image = self.packages.${system}.pxe-server-image.override {
            butane = markerButane;
            kernelArgs = [ "console=ttyS0,115200n8" ];
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
                butane = markerButane;
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

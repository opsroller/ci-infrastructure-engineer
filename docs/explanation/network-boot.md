# How the network boot works

## Proxy-DHCP instead of a second DHCP server

Most LANs already have a DHCP server, usually the router. A second
server that also hands out addresses would conflict with it. In
proxy-DHCP mode, dnsmasq leaves addresses to the existing server. It
answers only a PXE client's request for boot information: which file
to load and where to get it. The LAN needs no changes, and turning the
service off removes it completely.

## Why the firmware gets iPXE first

UEFI firmware can only fetch a small file over TFTP, which is slow and
has no scripting. iPXE is handed over first because it speaks HTTP,
which is far faster for the roughly 1 GB of Fedora CoreOS images. The
iPXE binary has a script compiled in that says to get an address and
chain `boot.ipxe` from this host. When iPXE starts, it sends its own
DHCP request and the proxy offers `ipxe.efi` again. The compiled-in
script replaces iPXE's normal autoboot, so that second offer is never
followed and the boot cannot loop.

## Finding the server without a fixed address

The server may get its own address from DHCP, so nothing about it is
built in. dnsmasq reads the subnet from its interface when it starts.
The proxy-DHCP answer carries the server's address as `next-server`.
iPXE stores that as `${proxydhcp/next-server}` and puts it in every
URL it fetches, kernel arguments included.

## A guest instead of a host service

Proxy-DHCP and TFTP need root on the machine that runs them. As a
libvirt guest on macvtap, the server is its own machine on the LAN.
The host's system config stays unchanged, and anyone allowed to manage
libvirt guests can add or remove the server. Its disk is a volume in a
libvirt storage pool, like any other guest's.

## Live or installed

By default, machines run Fedora CoreOS live: the whole OS sits in RAM
and Ignition configures it on every boot. Nothing persists, which suits
throwaway CI workers. Setting `installDevice` writes Fedora CoreOS to a
disk instead. The installed system then upgrades itself atomically with
rpm-ostree or bootc, and can carry a layered image on top. After an
install, a machine must boot from disk before the network, or it will
reinstall itself on every boot.

## Pinned images

The live images are fetched with `fetchurl` against the SHA-256 values
in Fedora's stream metadata. A rebuild of the same commit therefore
serves the same bits. Upgrading is a reviewed one-file change to
`nix/fcos-pin.json`. The images live in the Nix store, never in a
project folder.

## Secure Boot

The iPXE binary is built from source and not signed, so machines must
boot with Secure Boot off.

# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "squeakbox";

  time.timeZone = "Europe/Berlin";

  networking.useDHCP = false;
  networking.enableIPv6 = false;
  networking.interfaces.enp0s20u2u4.useDHCP = true;
  networking.interfaces.eno1.ipv4.addresses = [];
  networking.interfaces.eno2.ipv4.addresses = [];

  systemd.services.create-macvlans = {
    path = [ pkgs.iproute2 ];
    script = ''
      ip link delete macvtap0 || true
      ip link delete macvtap1 || true

      ip link add link eno1 name macvtap0 type macvtap mode passthru
      ip link add link eno2 name macvtap1 type macvtap mode passthru

      ip link set macvtap0 up
      ip link set macvtap1 up
    '';
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  system.stateVersion = "21.11";
}

# Deploy me with:
#
# nixos-rebuild boot --flake .#big-edge --target-host demo@172.27.30.100 --use-remote-sudo --builders ""

{ config, pkgs, modulesPath, lib, ... }:

{
  imports = [
    ../common.nix    
    ./hardware-configuration.nix
  ];

  # Prevent blank screen on booting.
  boot.kernelParams = [ "nomodeset" ];

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  time.timeZone = "Europe/Berlin";
  networking.hostName = "big-edge"; # Define your hostname.

  networking = {
    useDHCP = false;
    enableIPv6 = false;

    interfaces = {
      # This is the right most port on the box. We use this as "management" port.
      enp3s0.useDHCP = true;

      # Everything else should not be autoconfigured.
      enp1s0.ipv4.addresses = [];
      enp2s0.ipv4.addresses = [];
      enp4s0.ipv4.addresses = [];
    };
  };

  system.stateVersion = "21.11"; # Did you read the comment?
}

{ config, pkgs, modulesPath, lib, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/qemu-vm.nix")
    (modulesPath + "/profiles/minimal.nix")
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "console=ttyS0" ];

  virtualisation = {
    memorySize = 512;
    graphics = false;
    writableStore = false;

    qemu = {
      networkingOptions = lib.mkForce [];
    };
  };

  networking = {
    # Don't change this, because it determines the name of the script
    # that starts this VM. This name is hardcoded in vm-service.nix.
    hostName = "fwd";

    useDHCP = false;
    enableIPv6 = false;
  };

}

{ config, pkgs, modulesPath, lib, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  # Nothing here yet.
  networking.hostName = "fwd";
  virtualisation = {
    memorySize = 512;
    graphics = false;
    writableStore = false;

    qemu = {
      networkingOptions = lib.mkForce [];
    };
  };
}

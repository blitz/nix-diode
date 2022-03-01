{ config, pkgs, modulesPath, lib, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  # Nothing here yet.
  networking.hostName = "fwd";
}

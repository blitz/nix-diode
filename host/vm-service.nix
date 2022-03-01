# Adapted from https://nixos.wiki/wiki/Adding_VMs_to_PATH
{ configuration,
  # Must be unique, because we use it as systemd service name.
  name }:
{ config, pkgs, modulesPath, lib, ... }:
let
  nixos-system = pkgs.nixos configuration;
  nixos-vm = nixos-system.vm;
in {
  systemd.services.${name} = {
    wantedBy = [ "multi-user.target" ];

    wants = [ "create-macvlans" ];
    after = [ "create-macvlans" ];

    restartIfChanged = true;

    path = [
      nixos-vm
    ];

    environment = {
      QEMU_NET_OPTS = "";
      QEMU_ARGS = "-vga none -display none -serial stdio -m 512M";

      # We want stateless VMs.
      NIX_DISK_IMAGE = "/nonexistent";
    };
    script = "run-fwd-vm";
  };
}

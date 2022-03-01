# Adapted from https://nixos.wiki/wiki/Adding_VMs_to_PATH
{ configuration,
  # Must be unique, because we use it as systemd service name.
  name,

  # The tap device to connect the VM to. This is /dev/tapX.
  macvtap
}:
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
      # We want stateless VMs.
      NIX_DISK_IMAGE = "/nonexistent";
    };
    script = ''
      TAP_DEVICE=/dev/$(ls /sys/class/net/${macvtap}/macvtap | head -n1)

      export QEMU_OPTS="-nographic -serial stdio -monitor none"
      # TODO -net nic,model=virtio,addr=1a:46:0b:ca:bc:7b -net tap,fd=3 3<>$TAP_DEVICE
      run-fwd-vm
    '';
  };
}

## Adapted from https://nixos.wiki/wiki/Adding_VMs_to_PATH
#{ configuration,
#  # Must be unique, because we use it as systemd service name.
#  name,
#
#  # The network device to connect the VM to. This is /dev/tapX.
#  nic,
#
#  # The guest "address" in the vhost world. Needs to be >= 3 and unique.
#  cid
#}:
{ config, pkgs, modulesPath, lib, ... }:
let
  nixos-system = pkgs.nixos ./fwd-vm.nix;
  nixos-vm = nixos-system.vm;

  inherit (lib) mkOption mkIf types;

  networkCompartments = config.compartments.network;

  toService = name: { nic, cid }: {
    wantedBy = [ "multi-user.target" ];

    restartIfChanged = true;

    path = [
      nixos-vm
      pkgs.iproute2
    ];

    script = let
      macvtap = "macvtap-${name}";
    in ''
      ip link delete ${macvtap} || true
      ip link add link ${nic} name ${macvtap} type macvtap mode passthru
      ip link set ${macvtap} up

      TAP_DEVICE=/dev/$(ls /sys/class/net/${macvtap}/macvtap | head -n1)

      mkdir -p /var/lib/vms
      export NIX_DISK_IMAGE="/var/lib/vms/${name}"
      rm -f "$NIX_DISK_IMAGE"

      export QEMU_OPTS="-nographic -serial stdio -monitor none -device vhost-vsock-pci,guest-cid=${builtins.toString cid} -net nic,model=virtio -net tap,fd=3"

      run-fwd-vm 3<>$TAP_DEVICE
    '';
  };

in {
  options = {
    compartments.network = mkOption {
      type = types.attrs; # this lack of structure and documentation can be improved
      default = [];
      example = {
        fwd0 = {
          nic = "enp1s0"; # The network device to connect the VM to. This is /dev/tapX.
          cid = 3; # The guest "address" in the vhost world. Needs to be >= 3 and unique.
        };
        fwd1 = { nic = "enp2s0"; cid = 4; };
      };
    };
  };

  config = let
    services = pkgs.lib.mapAttrs toService networkCompartments;
  in mkIf (services != {}) { systemd.services = services; };
}

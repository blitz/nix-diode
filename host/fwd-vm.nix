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
    interfaces.eth0.ipv4.addresses = [];
  };

  systemd.services.netfwd = {
    wantedBy = [ "multi-user.target" ];

    #wants = [ "network-online.service" ];

    restartIfChanged = true;

    path = [
      pkgs.socat pkgs.iproute2 pkgs.inetutils pkgs.pciutils
    ];

    script = ''
      ip link delete macvtap0 || true
      ip link add link eth0 name macvtap0 type macvtap mode passthru
      ip link set macvtap0 up

      # XXXX We are losing the packet boundaries.
      socat OPEN:"/dev/$(ls /sys/class/net/macvtap0/macvtap | head -n1)" VSOCK-LISTEN:2000,forever,interval=10,fork &> /dev/console
    '';
  };

}

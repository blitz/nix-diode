{ config, pkgs, modulesPath, lib, ... }:

{
  imports = [
    #(modulesPath + "/profiles/minimal.nix")
    #(modulesPath + "/profiles/headless.nix")
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  #systemd.services."serial-getty@ttyS0".enable = true;

  virtualisation = {
    memorySize = 4096;
    cores = 4;

    # We need mkForce to nuke the userspace networking that gets added by qemu-vm.nix
    qemu.networkingOptions = lib.mkForce [
      # TODO We wnat to actually put packets in here...
      "-netdev user,id=in,restrict=on"
      "-device virtio-net,netdev=in,mac=52:54:00:12:34:56"

      # ... and take them out here.
      "-netdev user,id=out,restrict=on"
      "-device virtio-net,netdev=out,mac=52:54:00:12:34:57"
    ];
  };

  # User account for poking the system.
  users.users.demo = {
    isNormalUser = true;
    description = "Demo user account";
    extraGroups = [ "wheel" ];
    password = "demo";
    uid = 1000;
  };

  # Disable host networking as much as possible.
  networking = {
    enableIPv6 = false;
    useDHCP = false;
    interfaces = {
      eth0.ipv4.addresses = [];
      eth1.ipv4.addresses = [];
    };

    # There is a macvlans option that creates macvlan interfaces, but
    # for some reason we don't get the corresponding tap devices.
  };

  systemd.services.create-macvlans = {
    path = [ pkgs.iproute2 ];
    script = ''
      ip link add link eth0 name macvtap0 type macvtap mode passthru
      ip link add link eth1 name macvtap1 type macvtap mode passthru

      ip link set macvtap0 up
      ip link set macvtap1 up
    '';
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_administration_guide/sect-attch-nic-physdev
  # https://nixos.wiki/wiki/Adding_VMs_to_PATH
}

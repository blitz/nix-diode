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

    # There is a macvlans option that creates macvlan interfaces, but
    # for some reason we don't get the corresponding tap devices.
    # macvlans = {
    #   tap0 = {
    #     interface = "enp1s0";
    #     mode = "passthru";
    #   };
    #   tap1 = {
    #     interface = "enp2s0";
    #     mode = "passthru";
    #   };
    # };
  };

  systemd.services.create-macvlans = {
    path = [ pkgs.iproute2 ];
    script = ''
      ip link delete macvtap0 || true
      ip link delete macvtap1 || true

      ip link add link enp1s0 name macvtap0 type macvtap mode passthru
      ip link add link enp2s0 name macvtap1 type macvtap mode passthru

      ip link set macvtap0 up
      ip link set macvtap1 up
    '';
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_administration_guide/sect-attch-nic-physdev
  # https://nixos.wiki/wiki/Adding_VMs_to_PATH

  system.stateVersion = "21.11"; # Did you read the comment?
}

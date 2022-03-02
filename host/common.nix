{ config, pkgs, modulesPath, lib, ... }:

{
  imports = [
    (import ./vm-service.nix {
      name = "fwd0";
      configuration = import ./fwd-vm.nix;
      macvtap = "macvtap0";
      cid = 3;
    })

    (import ./vm-service.nix {
      name = "fwd1";
      configuration = import ./fwd-vm.nix;
      macvtap = "macvtap1";
      cid = 4;
    })
  ];

  # Living on the edge.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "mitigations=off" ];

  # For vsock sockets.
  boot.kernelModules = [ "vhost_vsock" ];

  services.chrony.enable = true;
  services.openssh.enable = true;

  users.users.demo = {
     isNormalUser = true;
     extraGroups = [ "wheel" "kvm" ]; # Enable ‘sudo’ for the user.
     initialPassword = "demodemo";
  };

  environment.systemPackages = with pkgs; [
    vim
    zile
    tmux
    htop
    dstat
    bottom
    socat
    pv
  ];

  nix = {
    trustedUsers = [ "root" "demo" ];
    package = pkgs.nix_2_4;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # For convenient deployment.
  security.sudo.wheelNeedsPassword = false;

  # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_administration_guide/sect-attch-nic-physdev
  # https://nixos.wiki/wiki/Adding_VMs_to_PATH
}

{ config, pkgs, modulesPath, lib, ... }:

{
  imports = [
    ./network-compartment.nix
  ];

  compartments.network = {
    fwd0 = { nic = "enp1s0"; cid = 3; };
    fwd1 = { nic = "enp2s0"; cid = 4; };
  };

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

  networking.firewall.enable = false;

  # For convenient deployment.
  security.sudo.wheelNeedsPassword = false;

  # Avoid filling up the disk.
  services.journald.extraConfig = ''
    SystemMaxUse=250M
    SystemMaxFileSize=50M
  '';
}

{ config, pkgs, modulesPath, lib, ... }:

{
  imports = [
    (import ./vm-service.nix {
      name = "fwd0";
      configuration = import ./fwd-vm.nix;
      nic = "enp1s0";
      cid = 3;
    })

    (import ./vm-service.nix {
      name = "fwd1";
      configuration = import ./fwd-vm.nix;
      nic = "enp2s0";
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

  networking.firewall.enable = false;

  # For convenient deployment.
  security.sudo.wheelNeedsPassword = false;

  # Avoid filling up the disk.
  services.journald.extraConfig = ''
    SystemMaxUse=250M
    SystemMaxFileSize=50M
  '';
}

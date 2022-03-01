{ config, pkgs, modulesPath, lib, ... }:

{
  imports = [
    (import ./vm-service.nix {
      name = "fwd0";
      configuration = import ./fwd-vm.nix;

      # XXX This device does not work. I assume we want to refactor things to use PCI passthrough.
      macvtap = "macvtap1";
    })
  ];

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

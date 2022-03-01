{ pkgs, lib, config, ... }:

let
  vfio-takeover = pkgs.writeScript "vfio-takeover" ''
    set -euo pipefail

    pciId=$1

    vendor=$(</sys/bus/pci/devices/$pciId/vendor)
    vendor=''${vendor#0x}
    device=$(</sys/bus/pci/devices/$pciId/device)
    device=''${device#0x}

    driver=$(basename $(readlink /sys/bus/pci/devices/$pciId/driver))

    echo $pciId > /sys/bus/pci/drivers/$driver/unbind
    echo $vendor $device > /sys/bus/pci/drivers/vfio-pci/new_id
  '';

  inherit (lib) mkOption mkIf types;

  cfg = config.services.vfio-takeover;
in
{
  options = {
    services.vfio-takeover = {
      pciIds = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "0000:00:19.0" "0000:02:00.0" ];
      };
    };
  };

  config = mkIf (builtins.length cfg.pciIds > 0) {
    boot.kernelModules = [ "vfio-pci" ];

    systemd.services.vfio-takeover = {
      description = "VFIO Takeover Service";
      wantedBy = [ "network.target" ];

      script = ''
        set -euo pipefail
        for pciId in ${builtins.toString cfg.pciIds}; do
          ${vfio-takeover} "$pciId"
        done
      '';
    };
  };
}

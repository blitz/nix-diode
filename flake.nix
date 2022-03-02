{
  description = "A very basic flake";

  inputs = rec {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nix-community/naersk";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
  };

  outputs = { self, nixpkgs, utils, naersk, flake-compat, flake-compat-ci }:
    let
      flakeAttrs = (utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages."${system}";
      naersk-lib = naersk.lib."${system}";
      in rec {
        # `nix build`
        packages.pkt_fwd = naersk-lib.buildPackage {
          pname = "pkt_fwd";
          root = ./pkt_fwd;
        };
        defaultPackage = packages.pkt_fwd;

        # `nix develop`
        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ rustc cargo ];
        };
      }));

      pkt_fwd_module = ({...}: {
              nixpkgs.overlays = [
                (final: prev: {
                  pkt_fwd = flakeAttrs.defaultPackage.x86_64-linux;
                })
              ];
            });
    in flakeAttrs // {
      nixosConfigurations = {
        big-edge = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./host/big-edge/configuration.nix
            pkt_fwd_module
          ];
        };
        squeakbox = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./host/squeakbox/configuration.nix
            pkt_fwd_module
          ];
        };
      };
    } // {

    # For Hercules CI, which doesn't natively support flakes (yet).
    ciNix = flake-compat-ci.lib.recurseIntoFlakeWith {
      flake = self;

      # Optional. Systems for which to perform CI.
      systems = [ "x86_64-linux" ];
    };
  };
}

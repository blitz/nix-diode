{
  description = "A very basic flake";

  inputs = rec {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
  };

  outputs = { self, nixpkgs, flake-compat, flake-compat-ci }: {

    nixosConfigurations = {
      diode = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./host/configuration.nix
        ];
      };
    };

    # For Hercules CI, which doesn't natively support flakes (yet).
    ciNix = flake-compat-ci.lib.recurseIntoFlakeWith {
      flake = self;

      # Optional. Systems for which to perform CI.
      systems = [ "x86_64-linux" ];
    };
  };
}

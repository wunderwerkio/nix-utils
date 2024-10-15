{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: let
    systems = import ./nix/systems.nix;
  in {
    inherit systems;

    packages = systems.eachDefaultSystemPassThrough(system: let
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      devenv-helper = import ./nix/devenv-helper.nix {
        inherit pkgs;
      };
    })
  };
}

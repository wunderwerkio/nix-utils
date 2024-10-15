{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = import ./nix/systems.nix {};
  in
    {
      lib = {
        inherit systems;
      };
    }
    // systems.eachDefault (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
      env-sh = import ./nix/scripts/env-sh.nix {
        inherit pkgs;
      };
      utils-sh = import ./nix/scripts/utils-sh.nix {
        inherit pkgs;
      };
      print-sh = import ./nix/scripts/print-sh.nix {
        inherit pkgs utils-sh;
      };
      devenv-sh = import ./nix/scripts/devenv-sh.nix {
        inherit pkgs env-sh print-sh;
      };
    in {
      packages = {
        inherit env-sh print-sh utils-sh devenv-sh;
      };

      formatter = pkgs.alejandra;
    });
}

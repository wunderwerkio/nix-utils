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
    in {
      packages = {
        devenv-helper = import ./nix/devenv-helper.nix {
          inherit pkgs;
        };
      };

      formatter = pkgs.alejandra;
    });
}

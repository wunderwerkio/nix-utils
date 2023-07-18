{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = [
      # Linux machines
      "x86_64-linux"
      "aarch64-linux"
      # MacOS machines
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  in {
    lib = {
      # Function that generates an attribute set for each
      # system that the wunderwerk team uses for development.
      # See: https://github.com/NixOS/nixpkgs/blob/f64b9738da8e86195766147e9752c67fccee006c/lib/attrsets.nix#L613
      forEachWunderwerkSystem = nixpkgs.lib.genAttrs systems;
    };

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
  };
}

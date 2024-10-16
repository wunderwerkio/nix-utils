{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";

    utils.url = "github:wunderwerkio/nix-utils";
    utils.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    utils,
    nixpkgs,
  }: {
    lib = {
      my-lib = import ./my-lib.nix
    };

    packages = utils.lib.systems.eachDefaultMapped (system: let 
      # Imports the pkgs for the current system.
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      default = import ./my-package.nix {
        inherit pkgs;
      };
    });

    devShells = utils.lib.systems.eachDefaultMapped (system: let
      # Imports the pkgs for the current system.
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      default = pkgs.mkShell {
        buildInputs = [
          pkgs.php81

          setup-drupal
        ];
      };
    };

    formatter = utils.lib.systems.eachDefaultMapped (system: let
      # Imports the pkgs for the current system.
      pkgs = import nixpkgs {
        inherit system;
      };
    in pkgs.alejandra;
  };
}

# Results in (outputs):
#
# {
#   lib = {
#     my-lib = import ./my-lib.nix 
#   };
#
#   packages = {
#     "x86_64-linux" = let
#       pkgs = import nixpkgs {
#         system = "x86_64-linux";
#       };
#     in {
#       default = import ./my-package.nix {
#         inherit pkgs;
#       };
#     };
#     "aarch64-linux" = let
#       pkgs = import nixpkgs {
#         system = "aarch64-linux";
#       };
#     in {
#       default = import ./my-package.nix {
#         inherit pkgs;
#       };
#     };
#     "x86_64-darwin" = {}  # Same as above...
#     "aarch64-darwin" = {} # Same as above...
#   };
#
#   devShells = {
#     "x86_64-linux" = let
#       pkgs = import nixpkgs {
#         system = "x86_64-linux";
#       };
#     in {
#       default = pkgs.mkShell {
#         buildInputs = [
#           pkgs.php81
#
#           setup-drupal
#         ];
#       };
#     };
#     "aarch64-linux" = {
#       pkgs = import nixpkgs {
#         system = "aarch64-linux";
#       };
#     in {
#       default = pkgs.mkShell {
#         buildInputs = [
#           pkgs.php81
#
#           setup-drupal
#         ];
#       };
#     };
#     "x86_64-darwin" = {}  # Same as above...
#     "aarch64-darwin" = {} # Same as above...
#   };
# 
#   formatter = {
#     "x86_64-linux" = let
#       pkgs = import nixpkgs {
#         system = "x86_64-linux";
#       };
#     in pkgs.alejandra;
#     "aarch64-linux" = let
#       pkgs = import nixpkgs {
#         system = "aarch64-linux";
#       };
#     in pkgs.alejandra;
#     "x86_64-darwin" = {}  # Same as above...
#     "aarch64-darwin" = {} # Same as above...
#   };
# }
#


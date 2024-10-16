# Nix Utils

Opinionated collection of various Nix utilies and Nix-specific bash scripts
for use in other Nix Flakes.

This Flake provides the following:

- **Nix utilities**
  System related utilities taken from [numtide/flake-utils](https://github.com/numtide/flake-utils)
- **Utility Bash functions**
  Common functionality as bash functions that can be sourced in
  scripts of other Nix Flakes.

## Nix Utilities

### Systems

Utilities related to systems.  
Helps generating the required attribute sets for each supported system in your flake.

This is taken from [numtide/flake-utils](https://github.com/numtide/flake-utils),
so all credit goes to them!

#### `lib.systems.eachDefault`

Same as `lib.systems.eachSystem` but populated with each system defined in `defaultSystems`.

#### `lib.systems.eachSystem :: [<system>]`

Builds a map from `<attr> = value` to `<attr>.<system> = value` for each system.

**Example:**

```nix
inputs.utils.lib.systems.eachSystem ["x86_64-linux"] (system: {
    packages = {
        default = import ./my-package.nix;
    };
})

# Results in:
{
    packages = {
        "x86_64-linux" = {
            default = import ./my-package.nix;
        };
    };
}
```

#### `lib.systems.defaultSystems`

A list with all default systems that are used for the `Default` functions.

Defaults to:

```nix
[
    "aarch64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
    "x86_64-linux"
]
```

#### `lib.systems.eachDefaultMapped`

Same as `lib.systems.eachSystemMapped` but populated with each system defined
in `defaultSystems`.

#### `lib.systems.eachSystemMapped :: [<system>]`

Builds a map from `<attr> = value` to `<system>.<attr> = value` for each system.

**Example:**

```nix
inputs.utils.lib.systems.eachSystemMapped ["x86_64-linux"] (system: {
    packages = {
        default = import ./my-package.nix;
    };
})

# Results in:
{
    "x86_64-linux" = {
        packages = {
            default = import ./my-package.nix;
        };
    };
}
```

#### `lib.systems.eachDefaultPassthrough`

Same as `lib.systems.eachSystemPassthrough` but populated with each system defined
in `defaultSystems`.

#### `lib.systems.eachSystemPassthrough :: [<system>]`

Just provides a callback with the `system` argument, does not alter
the attribute set.

**Example:**

```nix
inputs.utils.lib.systems.eachSystemPassthrough ["x86_64-linux"] (system: {
    packages = {
        default = import ./my-package.nix;
    };
})

# Results in:
{
    packages = {
        default = import ./my-package.nix;
    };
}
```

## Utility Bash functions

Useful bash functions can be sourced in other bash scripts.

Just import the functions that you need in your script.  
The bash functions can then directly be called.

See the scripts in `./nix/scripts/*` for the available functions
and their corresponding documentation.

**Example:**

```nix
#
# Import the packages for your system:
# inputs.utils.lib.system.eachDefaultSystem (system: {
#    utilsPkgs = inputs.utils.packages.${system};
# });
#
pkgs.writeShellScript ''
    source ${utilsPkgs.env-sh}
    source ${utilsPkgs.utils-sh}
    source ${utilsPkgs.git-sh}
    source ${utilsPkgs.print-sh}
    source ${utilsPkgs.devenv-sh}
'';
```

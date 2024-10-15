# The following code is taken from the awesome
# https://github.com/numtide/flake-utils flake!
# All credit goes to them!
{
  # Default supported systems.
  defaultSystems ? [
    "aarch64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
    "x86_64-linux"
  ],
}: let
  inherit defaultSystems;

  # eachSystem using defaultSystems
  eachDefault = eachSystem defaultSystems;

  # eachSystemPassthrough using defaultSystems
  eachDefaultPassthrough = eachSystemPassthrough defaultSystems;

  # Builds a map from <attr> = value to <attr>.<system> = value for each system.
  eachSystem = eachSystemOp (
    # Merge outputs for each system.
    f: attrs: system: let
      ret = f system;
    in
      builtins.foldl' (
        attrs: key:
          attrs
          // {
            ${key} =
              (attrs.${key} or {})
              // {
                ${system} = ret.${key};
              };
          }
      )
      attrs (builtins.attrNames ret)
  );

  # Applies a merge operation accross systems.
  eachSystemOp = op: systems: f:
    builtins.foldl' (op f) {} (
      if !builtins ? currentSystem || builtins.elem builtins.currentSystem systems
      then systems
      else
        # Add the current system if the --impure flag is used.
        systems ++ [builtins.currentSystem]
    );

  # Merely provides the system argument to the function.
  #
  # Unlike eachSystem, this function does not inject the `${system}` key.
  eachSystemPassthrough = eachSystemOp (
    f: attrs: system:
      attrs // (f system)
  );

  # eachSystemMap using defaultSystems
  eachDefaultMapped = eachSystemMapped defaultSystems;

  # Builds a map from `<attr> = value` to `<system>.<attr> = value`.
  eachSystemMapped = systems: f:
    builtins.listToAttrs (builtins.map (system: {
        name = system;
        value = f system;
      })
      systems);
in {
  inherit
    defaultSystems
    eachDefault
    eachDefaultMapped
    eachDefaultPassthrough
    eachSystem
    eachSystemMapped
    eachSystemPassthrough
    ;
}

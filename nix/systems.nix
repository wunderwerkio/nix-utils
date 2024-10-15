{
  # Default supported systems.
  defaultSystems ? [
    "aarch64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
    "x86_64-linux"
  ]
}:
let
  inherit defaultSystems;

  # eachSystem using defaultSystems
  eachDefaultSystem = eachSystem defaultSystems;

  # eachSystemPassThrough using defaultSystems
  eachDefaultSystemPassThrough = eachSystemPassThrough defaultSystems;

  # Builds a map from <attr>=value to <attr>.<system>=value for each system.
  eachSystem = eachSystemOp (
    # Merge outputs for each system.
    f: attrs: system:
    let
      ret = f system;
    in
    builtins.foldl' (
      attrs: key:
      attrs
      // {
        ${key} = (attrs.${key} or { }) // {
          ${system} = ret.${key};
        };
      }
    ) attrs (builtins.attrNames ret)
  );

  # Applies a merge operation accross systems.
  eachSystemOp =
    op: systems: f:
    builtins.foldl' (op f) { } (
      if
        !builtins ? currentSystem || builtins.elem builtins.currentSystem systems
      then
        systems
      else
        # Add the current system if the --impure flag is used.
        systems ++ [ builtins.currentSystem ]
    );

  # Merely provides the system argument to the function.
  #
  # Unlike eachSystem, this function does not inject the `${system}` key.
  eachSystemPassThrough = eachSystemOp (
    f: attrs: system:
    attrs // (f system)
  );

  # eachSystemMap using defaultSystems
  eachDefaultSystemMap = eachSystemMap defaultSystems;

  # Builds a map from `<attr> = value` to `<system>.<attr> = value`.
  eachSystemMap = systems: f: builtins.listToAttrs (builtins.map (system: { name = system; value = f system; }) systems);

  lib = {
    inherit
      defaultSystems
      eachDefaultSystem
      eachDefaultSystemMap
      eachDefaultSystemPassThrough
      eachSystem
      eachSystemMap
      eachSystemPassThrough
    ;
  };
in lib

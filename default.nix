{ lib ? import <nixpkgs/lib>
, configuration
}:

let

  extendedLib = lib.extend (self: super: {
    types = super.types // {
      topo.path = with super.types; attrsOf (attrsOf (listOf str));
    };
  });

in extendedLib.evalModules {
  modules = [ ./module.nix configuration ];
}

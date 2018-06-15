{ lib, config, ... }:

with lib;

let

  hostType = types.submodule ({ name, ... }: {

    imports = [
      ./rssh.nix
      ./openvpn.nix
    ];

    options = {
      name = mkOption {
        type = types.str;
        description = "Host name, will coincide with the ones in topology";
      };
    };

    config = {

      # Might get infinite recursion
      _module.args.toponix = config;

      name = mkDefault name;
      hosts = config.hosts;
    };
  });

  topologyType = with types;
    let ip = nullOr str;
        subnet = attrsOf ip;
    in attrsOf (either ip subnet);

  endpointType = types.submodule {
    options.ip = mkOption {
      type = types.nullOr types.str;
    };

    options.subnet = mkOption {
      type = types.nullOr types.str;
    };
  };

  endpoints = let
    lists = mapAttrs (name: value:
      if builtins.isString value || builtins.isNull value then [{
        ${name} = {
          subnet = null;
          ip = value;
        };
      }] else map (subname: {
          ${subname} = {
            subnet = name;
            ip = value.${subname};
          };
      }) (builtins.attrNames value)
    ) config.topology;
    in foldAttrs (n: a: [n] ++ a) [] (concatLists (builtins.attrValues lists));

  direct = mapAttrs (from: fromValue:
      mapAttrs (to: toValue:
        unique (map (x: x.ip) (filter (x: elem x.subnet (map (y: y.subnet) fromValue)) toValue) ++ map (x: x.ip) (filter (x: x.subnet == null) toValue))
      ) endpoints
    ) endpoints;

  local = mapAttrs (from: fromValue:
    mapAttrs (to: toValue:
      if from == to then [ "127.0.0.1" ] else toValue
    ) fromValue
  );

in {

  imports = [
    ./rssh.nix
    ./openvpn.nix
  ];

  options = {
    topology = mkOption {
      type = topologyType;
      description = "Topology";
    };

    ordering = mkOption {
      type = types.listOf hostType;
      description = "ordering of the hosts";
    };

    endpoints = mkOption {
      type = types.attrsOf (types.listOf endpointType);
      readOnly = true;
      internal = true;
    };

    direct = mkOption {
      type = types.topo.path;
      default = local direct;
      readOnly = true;
    };

    combinedPaths = mkOption {
      type = types.topo.path;
      readOnly = true;
    };

    hosts = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      description = "all hosts in the topology";
    };
  };

  config = {
    hosts = mapAttrs (name: _: name) endpoints;

    endpoints = endpoints;

    combinedPaths = local (zipAttrsWith (name: values:
      zipAttrsWith (name2: values2: concatLists values2) values
    ) ([ direct ] ++ (optional config.openvpn.enable config.openvpn.paths) ++ (optional config.rssh.enable config.rssh.paths)));

  };

}

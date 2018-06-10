{ lib, config, ... }:

with lib;

let

  cfg = config.rssh;

in

{

  options.rssh = {
    enable = mkEnableOption "rssh";

    ipPorts = mkOption {
      type = types.unspecified;
    };

    server = mkOption {
      type = types.str;
    };

    clients = mkOption {
      type = types.listOf types.str;
    };

    paths = mkOption {
      type = types.topo.path;
      readOnly = true;
      description = "Paths via rssh";
    };
  };

  config.rssh.paths = let
    portForNode = listToAttrs (imap1 (i: v: nameValuePair v (cfg.ipPorts i))
      cfg.clients);
    # Will error when server doesn't have public ip
    serverIp = (head (filter (x: x.subnet == null) (config.endpoints.${cfg.server}))).ip;
    result = mapAttrs (from: fromValue:
      mapAttrs (to: toValue:
        optional (elem to cfg.clients) "${if from == cfg.server then "localhost" else serverIp}:${portForNode.${to}}"
      ) config.endpoints
    ) config.endpoints;
    in result;
}

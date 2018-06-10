{ lib, config, ... }:

with lib;

let

  cfg = config.openvpn;

in

{

  options.openvpn = {
    enable = mkEnableOption "openvpn";
 
    addresses = mkOption {
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
      description = "Paths via openvpn";
    };
  };

  config.openvpn.paths = let
    ipForNode = listToAttrs (imap1 (i: v: nameValuePair v (cfg.addresses i))
      ([ cfg.server ] ++ cfg.clients));
    result = mapAttrs (from: fromValue:
      mapAttrs (to: toValue:
        [ ipForNode.${to} ]
      ) config.endpoints
    ) config.endpoints;
    in if any (x: x.subnet == null) (config.endpoints.${cfg.server}) then result else throw
      "The node \"${cfg.server}\" used as the openvpn server doesn't have a public ip address";
}

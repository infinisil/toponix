with import <nixpkgs/lib>;
with builtins;

rec {
  init = { ip = 2; port = 2762; };
  ipPort = ip: port: {
    inherit ip port;
  };

  ip22 = ip: ipPort ip 22;
  localhost = "127.0.0.1";

  vpnServerIp = vpnIp { ip = 1; };
  vpnIp = { ip }: ip22 "10.149.76.${toString ip}";
  sshPort = { port }: ipPort "207.154.198.134" port;

  subnet = gateway: hosts: hosts;

  # an ip means static ip, null means non-static ip
  # top-level means public, nested means private
  topology = {
    home = {
      pc = "192.168.1.25";
      laptop = "192.168.1.19";
    };
    otherserver = "164.165.203.40";
    server = "207.154.198.134";
    public = {
      laptop = null;
    };
  };

  converted = let
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
    ) topology;
    in foldAttrs (n: a: [n] ++ a) [] (concatLists (builtins.attrValues lists));

  # Direct connection from host to host
  direct = mapAttrs (from: fromValue:
      mapAttrs (to: toValue:
        unique (map (x: x.ip) (filter (x: elem x.subnet (map (y: y.subnet) fromValue)) toValue) ++ map (x: x.ip) (filter (x: x.subnet == null) toValue))
      ) converted
    ) converted;

  openvpn = let
    nodes = mapAttrs (n: v: n) converted;
    settings = openvpnSettings nodes;
    ipForNode = listToAttrs (imap1 (i: v: nameValuePair v (settings.addresses i))
      ([ settings.server ] ++ settings.clients));
    result = mapAttrs (from: fromValue:
      mapAttrs (to: toValue:
        [ ipForNode.${to} ]
      ) converted
    ) converted;
    in if any (x: x.subnet == null) (converted.${settings.server}) then result else throw
      "The node \"${settings.server}\" used as the openvpn server doesn't have a public ip address";

  rsshSettings = hosts: {
    ipPorts = n: toString (6726 + n);
    server = hosts.server;
    clients = with hosts; [
      pc
      laptop
    ];
  };

  rssh = let
    nodes = mapAttrs (n: v: n) converted;
    settings = rsshSettings nodes;
    portForNode = listToAttrs (imap1 (i: v: nameValuePair v (settings.ipPorts i))
      settings.clients);
    # Will error when server doesn't have public ip
    serverIp = (head (filter (x: x.subnet == null) (converted.${settings.server}))).ip;
    result = mapAttrs (from: fromValue:
      mapAttrs (to: toValue:
        optional (elem to settings.clients) "${if from == settings.server then "localhost" else serverIp}:${portForNode.${to}}"
      ) converted
    ) converted;
    in result;

  almostFinal = zipAttrsWith (name: values:
      zipAttrsWith (name2: values2: concatLists values2) values
    ) [ direct openvpn rssh ];

  final = mapAttrs (from: fromValue:
    mapAttrs (to: toValue:
      if from == to then [ "127.0.0.1" ] else toValue
    ) fromValue
  ) almostFinal;

  openvpnSettings = hosts: {
    addresses = n: "10.176.75.${toString n}";
    server = hosts.server;
    clients = with hosts; [
      pc
      laptop
      otherserver
    ];
  };

  topology2 = {
    pc = [
      {
        subnet = "home";
        ip = "192.168.1.25";
      }
    ];
    laptop = [
      {
        subnet = "home";
        ip = "192.168.1.19";
      }
      {
        subnet = "public";
        ip = null;
      }
    ];
    server = [
      {
        subnet = null;
        ip = "207.154.198.134";
      }
    ];
    otherserver = [
      {
        subnet = null;
        ip = "45.56.75.72";
      }
    ];
  };

  rules = hosts: with hosts; {
    remotePortForwardHost = host: if host == pc then server else otherserver; # used for reverse port forwarding
    order = [ server otherserver laptop pc ]; # used for openvpn ips
    
  };

  machines = {
    laptop = {
      id = 0;
    };
    pc = {
      id = 1;
    };
    yuri = {
      ip = 2;
    };
  };

  fillIps = n: v: let
    # Takes an integer and a recursive value
    # For every function in the value, apply the integer and increase it
    # Result is { n, result } where n is the next appliable integer, result is
    # the resulting recursive type
    apply = n: value:
      if isAttrs value then
        foldl ({ n, result }: attrName:
          let applied = apply n value.${attrName}; in {
            n = applied.n;
            result = result // {
              ${attrName} = applied.result;
            };
          }
        ) {
          inherit n;
          result = {};
        } (attrNames value)
      else if isList value then
        foldl ({ n, result }: el:
          let applied = apply n el; in {
            n = applied.n;
            result = result ++ [ applied.result ];
          }
        ) {
          n = n;
          result = [];
        } value
      else if isFunction value then
        let args = functionArgs value; in apply
          (mapAttrs (n: v: if elem n (attrNames args) then v + 1 else v) n)
          (value (intersectAttrs args n))
      else {
        n = n;
        result = value;
      };

    in (apply n v).result;

  intendedResult = fillIps { ip = 2; port = 2762; } {
    pc = {
      laptop = [
        {
          type = "private";
          ip = "192.168.1.19";
          port = 22;
        }
        {
          type = "openvpn";
          ip = "10.149.76.2";
          port = 22;
        }
        {
          type = "sshForward";
          ip = "207.154.198.134";
          port = 2762;
        }
      ];
      server = [
        {
          type = "openvpn";
          ip = "10.149.76.1";
          port = 22;
        }
        {
          type = "public";
          ip = "207.154.198.134";
          port = 22;
        }
      ];
      pc = [
        {
          type = "local";
          ip = "127.0.0.1";
          port = 22;
        }
      ];
    };
    laptop = {
      laptop = [
        {
          type = "local";
          ip = "127.0.0.1";
          port = 22;
        }
      ];
      pc = [
        {
          type = "private";
          ip = "192.168.1.25";
          port = 22;
        }
        {
          type = "openvpn";
          ip = "10.149.76.3";
          port = 22;
        }
        {
          type = "sshForward";
          ip = "207.154.198.134";
          port = 2763;
        }
      ];
      server = [
        {
          type = "openvpn";
          ip = "10.149.76.1";
          port = 22;
        }
        {
          type = "public";
          ip = "207.154.198.134";
          port = 22;
        }
      ];
    };
    server = {
      laptop = [
        {
          type = "openvpn";
          ip = "10.149.76.2";
          port = 22;
        }
        {
          type = "sshForward";
          ip = "207.154.198.134";
          port = 2762;
        }
      ];
      pc = [
        {
          type = "openvpn";
          ip = "10.149.76.3";
          port = 22;
        }
        {
          type = "sshForward";
          ip = "207.154.198.134";
          port = 2763;
        }
      ];
      server = [
        {
          type = "local";
          ip = "127.0.0.1";
          port = 22;
        }
      ];
    };
  };
}

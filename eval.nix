let

  lib = import <nixpkgs/lib>;

  config = { config, ... }: {

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

    rssh = {
      enable = true;
      ipPorts = n: toString (6726 + n);
      server = config.hosts.server;
      clients = with config.hosts; [
        pc
        laptop
      ];
    };

    openvpn = {
      enable = true;
      addresses = n: "10.176.75.${toString n}";
      server = config.hosts.server;
      clients = with config.hosts; [
        pc
        laptop
        otherserver
      ];
    };

  };

in

(lib.extend (self: super: {
  types = super.types // {
    topo.path = with super.types;
      attrsOf (attrsOf (listOf str));
  };
})).evalModules {
  modules = [ ./module.nix config ];
}

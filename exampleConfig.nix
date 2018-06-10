{ config, ... }: {

  topology = {
    home = {
      pc = "192.168.1.25";
      laptop = "192.168.1.19";
    };
    server = "76.174.19.220";
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
    ];
  };

}

{ ... }:

{
  services.fail2ban = {
    enable = true;
    jails.sshd.settings = {
      enabled = true;
      backend = "systemd";
      bantime = "1h";
      findtime = "10m";
      maxretry = 5;
    };
  };
}

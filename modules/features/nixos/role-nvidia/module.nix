{
  config,
  pkgs,
  ...
}: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.hardware.bolt.enable = true;

  environment.systemPackages = with pkgs; [
    bolt
    pciutils
  ];

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidiafb"
  ];
}

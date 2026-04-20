{
  config,
  pkgs,
  ...
}: {
  # External NVIDIA GPU support (eGPU / OCuLink / Thunderbolt).
  #
  # This keeps the integrated GPU available while enabling the proprietary
  # NVIDIA stack for systems that may attach an external NVIDIA card.
  #
  # Notes:
  # - NVIDIA Wayland support on Plasma requires modesetting.
  # - Thunderbolt eGPUs need bolt authorization support.
  # - PRIME offload/sync for rendering to the internal laptop display requires
  #   host-specific PCI bus IDs, so that should be added per-host later if needed.
  # - The AMD iGPU in the Ryzen AI / HX 375 class is handled by the normal
  #   amdgpu + Mesa stack already provided by hardware.graphics.
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
    # Required for Wayland and modern desktop sessions.
    modesetting.enable = true;

    # Prefer the proprietary kernel module stack for broadest compatibility.
    open = false;

    # Keep power management conservative for detachable external GPUs.
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

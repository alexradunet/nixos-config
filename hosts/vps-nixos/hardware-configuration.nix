# Replace this scaffold with the generated hardware file from the VPS itself:
#   sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix
# The placeholder below is only here so the flake can evaluate before the host
# has been provisioned.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

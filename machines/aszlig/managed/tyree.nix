{ config, pkgs, lib, ... }:

{
  boot.initrd.availableKernelModules = [ "usbhid" ];
  boot.kernelModules = [ "kvm-intel" ];

  boot.loader.gummiboot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  environment.systemPackages = with pkgs; [
    cdparanoia chromium figlet gajim gimp htop inkscape kde5.gwenview
    libreoffice mosh mpv pciutils skype thunderbird vlc vuizvui.tomahawk wget
    wine youtubeDL
  ];

  fileSystems."/boot".device = "/dev/disk/by-uuid/A0D5-269D";
  fileSystems."/boot".fsType = "vfat";

  fileSystems."/".label = "tyree-root";
  fileSystems."/".fsType = "btrfs";
  fileSystems."/".options = [
    "compress=lzo"
    "discard"
    "noatime"
    "space_cache"
    "ssd"
  ];

  swapDevices = lib.singleton {
    label = "tyree-swap";
  };

  hardware.cpu.intel.updateMicrocode = true;
  hardware.pulseaudio.enable = true;

  i18n.consoleKeyMap = "de";
  i18n.defaultLocale = "de_DE.UTF-8";

  networking.hostName = "tyree";
  networking.firewall.enable = false;
  networking.wireless.enable = false;
  networking.networkmanager.enable = true;
  networking.useNetworkd = true;

  nix.maxJobs = 4;
  nix.useChroot = true;
  nix.readOnlyStore = true;
  nix.buildCores = 0;
  nix.extraOptions = ''
    auto-optimise-store = true
  '';

  nixpkgs.config = {
    allowUnfree = true;
    pulseaudio = true;
    chromium.enablePepperFlash = true;
  };

  services.openssh.enable = true;
  services.tlp.enable = true;

  services.printing.enable = true;
  services.printing.drivers = [ pkgs.gutenprint pkgs.hplip ];

  services.xserver.enable = true;
  services.xserver.layout = "de";
  services.xserver.xkbOptions = "eurosign:e";
  services.xserver.displayManager.auto.enable = true;
  services.xserver.displayManager.auto.user = "bla";
  services.xserver.desktopManager.kde5.enable = true;
  services.xserver.wacom.enable = true;

  time.timeZone = "Europe/Berlin";

  users.users.bla = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "video" "wheel" ];
  };

  # XXX: Temporary until internal WiFi works
  vuizvui.hardware.rtl8192cu.enable = true;

  vuizvui.hardware.t100ha.enable = true;
  vuizvui.user.aszlig.programs.vim.enable = true;
}

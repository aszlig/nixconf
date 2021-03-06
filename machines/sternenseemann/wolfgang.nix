{ config, pkgs, lib, ... }:

let
  browser = rec {
    pkg = pkgs.firefox-wayland;
    bin = "${pkg}/bin/firefox";
  };

in {
  imports = [
    ./base-laptop.nix
    ./desktop-sway.nix
    ./wireguard.nix
    ./user-lukas.nix
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.kernelModules = [
    "kvm-intel"
    "snd-seq"
    "snd-rawmidi"
  ];

  fileSystems."/" = {
    device = "/dev/mapper/main";
    fsType = "btrfs";
  };

  fileSystems."/boot" = {
    device = "/dev/nvme0n1p1";
    fsType = "vfat";
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/198329ed-5038-4ad8-b8a6-e52921f2673d"; }
  ];

  nix.maxJobs = 4;

  boot.initrd.luks.devices = {
    "main".device = "/dev/nvme0n1p2";
    "swap".device = "/dev/nvme0n1p3";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "wolfgang";
    hosts = {
      "127.0.0.1" = [ "rocketchat" ];
    };
  };

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    vuizvui.sternenseemann.pass
    exfat borgbackup
    gnupg pinentry-gtk2 signing-party gpgme
    thunderbird
    jackline dino
    vuizvui.sternenseemann.texlive jabref
    youtube-dl mpv spotify
    newsboat
    ghc cabal-install cabal2nix
    sbcl rlwrap
    valgrind gdb
    docker-compose
    scribusUnstable gimp inkscape libreoffice
    audacity
    signal-desktop discord
    multimc
    vuizvui.profpatsch.nman
    vuizvui.sternenseemann.nix-env-diff
    vuizvui.sternenseemann.tep
    vuizvui.sternenseemann.t
    xdg_utils                  # xdg-open etc.
    networkmanagerapplet       # for nm-connection-ediotr
    imv zathura
    gnome.nautilus
    browser.pkg
    nix-output-monitor
    # TODO(sterni) depot.users.sterni.clhs-lookup
    hunspell
  ] ++ (with hunspellDicts; [ de-de en-gb-large en-us ]);

  environment.variables = {
    BROWSER = browser.bin;
  };

  services.tor = {
    enable = true;

    torsocks = {
      enable = true;
    };

    client = {
      enable = true;
    };
  };

  services.xserver = {
    videoDrivers = [ "intel" ];
  };

  vuizvui.profiles.tvl = {
    enable = true;
  };

  system.stateVersion = "unstable";
}

{
  labtop = {
    boot.kernelModules = [ "kvm-intel" ];
    boot.initrd.availableKernelModules = [
      "uhci_hcd" "ehci_pci" "ata_piix" "firewire_ohci" "usb_storage"
    ];

    vuizvui.hardware.thinkpad.enable = true;

    hardware.trackpoint.enable = false;

    networking.enableIntel3945ABGFirmware = true;

    users.users.kevin = {
      isNormalUser = true;
      password = "kevin";
    };
    users.users.root.password = "root";
  };

  hannswurscht = {
    nixpkgs.system = "i686-linux";
  };
}
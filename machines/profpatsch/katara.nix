{ config, pkgs, unfreeAndNonDistributablePkgs, lib, ... }:
let

  myLib  = import ./lib.nix  { inherit pkgs lib; };
  myPkgs = import ./pkgs.nix { inherit pkgs lib myLib; };

in {

  imports = [
    ./base.nix
  ];

  config = rec {

    #########
    # Kernel

    boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" ];
    boot.loader.grub.device = "/dev/sda";
    boot.initrd.luks.devices = [ { device = "/dev/sda2"; name = "cryptroot"; } ];

    ###########
    # Hardware

    fileSystems."/" = {
      device = "/dev/dm-0";
      fsType = "btrfs";
      options = [ "ssd" ];
    };

    fileSystems."/boot" = {
      device = "/dev/sda1";
      fsType = "ext3";
    };

    hardware.pulseaudio = {
      enable = true;
      zeroconf.discovery.enable = true;
      # for Pillars of Eternity
      support32Bit = true;
    };

    # needed by some games (TODO: general module for games)
    # hardware.opengl.driSupport32Bit = true;
    vuizvui.hardware.thinkpad.enable = true;

    ######
    # Nix

    nix.maxJobs = 4;
    # what was this activated for?!
    # vuizvui.enableGlobalNixpkgsConfig = true;

    ##########
    # Network

    networking.hostName = "katara";

    networking.networkmanager.basePackages =
      with pkgs; {
        # the openssl backend doesn’t like the protocols of my university
        networkmanager_openconnect =
          pkgs.networkmanager_openconnect.override { openconnect = pkgs.openconnect_gnutls; };
        inherit networkmanager modemmanager wpa_supplicant
                networkmanager_openvpn networkmanager_vpnc
                networkmanager_pptp networkmanager_l2tp;
    };


    ###########
    # Packages

    environment.systemPackages = with pkgs;
    let
      systemPkgs =
      [
        atool             # archive tools
        gnupg gnupg1compat # PGP encryption
        imagemagick       # image conversion
        pkgs.vuizvui.jmtpfs     # MTP fuse
        mosh              # ssh with stable connections
        nfs-utils         # the filesystem of the future for 20 years
        tarsnap           # encrypting online backup tool
        # TODO move into atool deps
        unzip             # extract zip archives
      ];
      xPkgs = [
        dmenu             # simple UI menu builder
        dunst             # notification daemon (interfaces with libnotify)
        alock             # lock screen
        libnotify         # notification library
        xclip             # clipboard thingy
        xorg.xkill        # X11 application kill
        # TODO get service to work (requires user dbus)
      ];
      guiPkgs = [
        gnome3.adwaita-icon-theme
        # TODO: get themes to work. See notes.org.
        gnome3.gnome_themes_standard
        pavucontrol
        networkmanagerapplet
      ];
      hp = haskellPackages;
      programmingTools = [
        cabal2nix            # convert cabal files to nixexprs
        cabal-install        # haskell project management
        myPkgs.fast-init     # fast-init of haskell projects
        gitAndTools.git-annex     # version controlled binary file storage
        # mercurial          # the other version control system
        telnet               # tcp debugging
      ];
      documentation = [
        # mustache-spec NOT IN 16.09
      ];
      userPrograms = [
        abcde                # high-level cd-ripper with tag support
        anki                 # spaced repetition system
        # TODO integrate lame into audacity
        audacity lame.lib    # audio editor and mp3 codec
        myPkgs.beets         # audio file metadata tagger
        # chromium             # browser
        (chromium.override { enablePepperFlash = true; })
        # droopy               # simple HTML upload server
        unfreeAndNonDistributablePkgs.dropbox-cli # dropbox.com client
        electrum             # bitcoin client
        emacs                # pretty neat operating system i guess
        feh                  # brother of meh, displays images in a meh way, but fast
        filezilla            # FTP GUI business-ready interface framework
        ghc                  # <s>Glorious</s>Glasgow Haskell Compiler, mostly for ghci
        gimp                 # graphics
        gmpc                 # mpd client and best music player interface in the world
        httpie               # nice http CLI
        inkscape             # vector graphics
        # libreoffice          # a giant ball of C++, that sometimes helps with proprietary shitformats
        lilyterm             # terminal emulator, best one around
        myPkgs.mpv           # you are my sun and my stars. and you play my stuff.
        newsbeuter           # RSS/Atom feed reader
        pass                 # standard unix password manager
        poppler_utils        # pdfto*
        ranger               # CLI file browser
        remind               # calender & reminder program
        rtorrent             # monster of a bittorrent client
        myPkgs.sent          # suckless presentation tool
        myPkgs.xmpp-client   # CLI XMPP Client
        youtube-dl           # download videos
        zathura              # pdf viewer
      ];
      userScripts = with pkgs.vuizvui; [
        profpatsch.display-infos  # show time & battery
        show-qr-code              # display a QR code
      ];
      mailPkgs = [
        elinks               # command line browser
        # myPkgs.offlineimap # IMAP client
        mutt-with-sidebar    # has been sucking less since 1970
        msmtp                # SMTP client
        notmuch              # mail indexer
        pythonPackages.alot  # the next cool thing!
      ];
      nixPkgs = [
        nix-repl                  # nix REPL
        nix-prefetch-scripts      # prefetch store paths from various destinations
      ];
      tmpPkgs = [
        # TODO needs user service
        redshift   # increases screen warmth at night (so i don’t have to feel cold)
      ];
    in systemPkgs ++ xPkgs ++ guiPkgs
    ++ programmingTools ++ documentation
    ++ userPrograms ++ userScripts
    ++ mailPkgs ++ nixPkgs ++ tmpPkgs;
    # system.extraDependencies = with pkgs; lib.singleton (
    #    # Haskell packages I want to keep around
    #    haskellPackages.ghcWithPackages (hpkgs: with hpkgs;
    #      [
    #        # frp
    #        frpnow
    #        gloss
    #        gtk
    #        frpnow-gtk
    #        frpnow-gloss

    #        lens
    #        wreq
    #        aeson-lens
    #      ]))
    #    ++
    #    # other packages that I use sometimes in a shell
    #    [
    #    ];

    ###########
    # Services

    services.searx.enable = true;

    services.printing = {
      enable = true;
      gutenprint = true;
      # TODO
      # drivers = [ pkgs.cups-pdf ];
      # TODO
      # drivers = [ pkgs.foomatic_filters pkgs.foomatic-db-engine ];
    };

    services.offlineimap = {
      # enable user service
      install = true;
      onCalendar = "*:0/15";
    };

    # redshift TODO as user
    services.redshift = {
      # enable = true;
      latitude = "48";
      longitude = "10";
      temperature.day = 6300;
    };

    # Automount
    services.udisks2.enable = true;

    ###################
    # Graphical System

    services.xserver = {
      enable = true;
      layout = "de";
      xkbVariant = "neo";
      xkbOptions = "altwin:swap_alt_win";
      serverFlagsSection = ''
        Option "StandbyTime" "10"
        Option "SuspendTime" "20"
        Option "OffTime" "30"
      '';
      synaptics = {
        enable = true;
        minSpeed = "0.5";
        accelFactor = "0.01";
        twoFingerScroll = true;
        vertEdgeScroll = false;
      };


      videoDrivers = [ "intel" ];

      # otherwise xterm is enabled, creating an xterm that spawns the window manager.
      desktopManager.xterm.enable = false;


      windowManager.xmonad = {
        enable = true;
        enableContribAndExtras = true;
      };

      # autorepeat = {
      #   enable = true;
      #   delay = 250;
      #   rate = 35;
      # };

      displayManager = {
        sessionCommands = with pkgs; ''
            #TODO add as nixpkg
            export PATH+=":$HOME/scripts" #add utility scripts
            export PATH+=":$HOME/.bin" #add (temporary) executables
            export EDITOR=emacsclient

            ${xorg.xset}/bin/xset r rate 250 35

            set-background &
            # TODO xbindkeys user service file
            ${lib.getBin xbindkeys}/bin/xbindkeys
            nice -n19 dropbox-cli start &
            nm-applet &
            # synchronize clipboards
            ${lib.getBin autocutsel}/bin/autocutsel -s PRIMARY &
            ${lib.getBin twmn}/bin/twmnd &
          '';
      };

    };

    fonts.fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "Source Code Pro" "DejaVu Sans Mono" ]; # TODO does not work
        sansSerif = [ "Liberation Sans" ];
      };
      ultimate.preset = "ultimate4";
      ultimate.substitutions = "combi";
    };
    fonts.fonts = with pkgs; [
      unfreeAndNonDistributablePkgs.corefonts
      source-han-sans-japanese
      source-han-sans-korean
      source-han-sans-simplified-chinese
      source-code-pro
      hasklig
      dejavu_fonts
      ubuntu_font_family
      league-of-moveable-type
    ];


    ###########
    # Programs

    vuizvui.programs.gnupg = {
      enable = true;
      agent = {
        enable = true;
        sshSupport = true;
      };
    };


    # TODO: base config?
    vuizvui.programs.fish.fasd.enable = true;

    # build derivation on taalo
    vuizvui.user.aszlig.programs.taalo-build.enable = true;

    vuizvui.user.profpatsch.programs.scanning.enable = true;

    #######
    # Misc

    security.pki.certificateFiles = [ "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];

    ########
    # Fixes

    # fix for emacs ssh
    programs.bash.promptInit = "PS1=\"# \"";

    ################
    # User services
    # systemd.user = {
    # };
  };
}

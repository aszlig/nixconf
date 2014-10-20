pkgs:

with pkgs.lib;

let
  allPackages = (import ../pkgs { pkgs = everything; }).vuizvui // misc;
  everything = pkgs // allPackages // drvOverrides // argOverrides;

  mapOverride = overrideFun: includePackages: let
    packages = pkgs // allPackages // includePackages;
    overrideName = name: overrideFun (getAttr name packages);
  in mapAttrs overrideName;

  # input attrset overrides using pkg.override
  argOverrides = mapOverride (getAttr "override") drvOverrides {
    netrw.checksumType = "mhash";
    pulseaudio.useSystemd = true;
    w3m.graphicsSupport = true;
    uqm.use3DOVideos = true;
    uqm.useRemixPacks = true;
    miro.enableBonjour = true;
  };

  gajimGtkTheme = everything.writeText "gajim.gtkrc" ''
    style "default" {
      fg[NORMAL] = "#d5faff"
      fg[ACTIVE] = "#fffeff"
      fg[SELECTED] = "#fffeff"
      fg[INSENSITIVE] = "#85aaaf"
      fg[PRELIGHT] = "#d7f2ff"

      text[NORMAL] = "#fffefe"
      text[ACTIVE] = "#fffeff"
      text[SELECTED] = "#fffeff"
      text[INSENSITIVE] = "#85aaaf"
      text[PRELIGHT] = "#d7f2ff"

      bg[NORMAL] = "#0f4866"
      bg[ACTIVE] = "#0c232e"
      bg[SELECTED] = "#005a56"
      bg[INSENSITIVE] = "#103040"
      bg[PRELIGHT] = "#1d5875"

      base[NORMAL] = "#0c232e"
      base[ACTIVE] = "#0f4864"
      base[SELECTED] = "#005a56"
      base[INSENSITIVE] = "#103040"
      base[PRELIGHT] = "#1d5875"
    }

    class "GtkWidget" style "default"

    gtk-enable-animations = 0
  '';

  gajimPatch = everything.substituteAll {
    src = ../pkgs/gajim/config.patch;
    nix_config = everything.writeText "gajim.config"
      (import ../cfgfiles/gajim.nix);
  };

  # derivation overrides
  drvOverrides = mapOverride overrideDerivation argOverrides {
    gajim = o: {
      patches = (o.patches or []) ++ singleton gajimPatch;
      postPatch = (o.postPatch or "") + ''
        sed -i -e '/^export/i export GTK2_RC_FILES="${gajimGtkTheme}"' \
          scripts/gajim.in
      '';
    };

    i3 = o: {
      patches = (o.patches or []) ++ (singleton (everything.fetchurl {
        url = "http://bugs.i3wm.org/report/raw-attachment/ticket/1332/"
            + "i3-validate-config-without-x.patch";
        sha256 = "1njmrvqr3h5wf8dwg5di136cjvnn5miaj7by3q93x8028hdpigag";
      }));
    };

    mpv = o: {
      installPhase = o.installPhase + ''
        cat > "$out/etc/mpv/mpv.conf" <<CONFIG
        ao=pulse
        CONFIG
      '';
    };

    nixops = o: let
      master = everything.fetchgit {
        url = "git://github.com/NixOS/nixops.git";
        rev = "523369cf3602a56f504c17432720c5b176f831f9";
        sha256 = "04svqdnwaf4h1bdgz92zm7hkzkg4niqvzl2vh5ivd72a051j7y2f";
      };
      release = import "${master}/release.nix" {
        officialRelease = true;
      };
      build = getAttr o.stdenv.system release.build;
    in with everything; build.drvAttrs // {
      name = "nixops-1.3git";
      patches = (build.drvAttrs.patches or []) ++ singleton (fetchpatch {
        url = "https://github.com/NixOS/nixops/pull/201.diff";
        sha256 = "1i5yycqayxggg3l1i6wk8lp64lqlxw5nmfya9fcrgmck8ls0rxid";
      });
      patchFlags = "--merge -p1";
    };
  };

  # misc
  misc = {
    kernelSourceVuizvui = {
      version = "3.18.0-rc1";
      src = everything.fetchgit {
        url = git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git;
        rev = "c2661b806092d8ea2dccb7b02b65776555e0ee47";
        sha256 = "0xk5vrvjmby26q06ja0xsf1jgi4115hrsw3b5nqhgrx37jc89zp5";
      };
    };

    testChromiumBuild = let
      buildChannels = [ "stable" "beta" "dev" ];
      buildChromium = chan: everything.chromium.override {
        channel = chan;
        gnomeSupport = true;
        gnomeKeyringSupport = true;
        proprietaryCodecs = true;
        cupsSupport = true;
        pulseSupport = true;
      };
      mkTest = chan: everything.writeScript "test-chromium-${chan}.sh" ''
        #!${everything.stdenv.shell}
        if datadir="$(${everything.coreutils}/bin/mktemp -d)"; then
          ${buildChromium chan}/bin/chromium --user-data-dir="$datadir"
          rm -rf "$datadir"
        fi
      '';
    in everything.stdenv.mkDerivation {
      name = "test-chromium-build";

      buildCommand = let
        chanResults = flip map buildChannels (chan: ''
          echo "Test script for ${chan}: ${mkTest chan}"
        '');
      in ''
        echo "Builds finished, the following derivations have been built:"
        ${concatStrings chanResults}
        false
      '';
    };
  };
in allPackages // drvOverrides // argOverrides

{ pkgs, config, lib, ... }:

let
  cfg = config.vuizvui.user.aszlig.services.vlock;

  messageFile = pkgs.runCommandLocal "message.cat" {} ''
    echo -en '\e[H\e[2J\e[?25l' > "$out"
    "${pkgs.vuizvui.aszlig.aacolorize}/bin/aacolorize" \
      "${./message.cat}" "${./message.colmap}" \
      >> "$out"
  '';

  esc = "\\\\033";
  unlockCSI = "${esc}[16;39H${esc}[?25h${esc}[K";

  vlock = lib.overrideDerivation pkgs.vlock (o: {
    postPatch = (o.postPatch or "") + ''
      echo -n '"' > src/message.h
      sed -e ':nl;N;$!bnl;s/[\\"]/\\&/g;s/\n/\\n/g' "${messageFile}" \
        >> src/message.h
      sed -i -e '$s/$/"/' src/message.h
      sed -i -e 's!getenv("VLOCK_MESSAGE")!\n#include "message.h"\n!' \
        src/vlock-main.c
      sed -i -re 's/(fprintf[^"]*")(.*user)/\1${unlockCSI}\2/' \
        src/auth-pam.c
    '';
  });
in {
  options.vuizvui.user.aszlig.services.vlock = {
    enable = lib.mkEnableOption "console lock";

    user = lib.mkOption {
      type = lib.types.str;
      example = "horst";
      internal = true;
      description = ''
        The user under which the locked session will run. This is a workaround
        and thus this option is solely internal.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.sockets.vlock = {
      description = "Console Lock Socket";
      wantedBy = [ "sockets.target" ];
      socketConfig.ListenStream = "/run/console-lock.sock";
      socketConfig.Accept = true;
    };

    systemd.services."vlock@" = {
      description = "Lock All Consoles";
      serviceConfig.Type = "oneshot";

      #environment.USER = "%i"; XXX
      environment.USER = cfg.user;

      script = ''
        retval=0
        oldvt="$("${pkgs.kbd}/bin/fgconsole")"
        "${vlock}/bin/vlock" -asn || retval=$?
        if [ $retval -ne 0 ]; then "${pkgs.kbd}/bin/chvt" "$oldvt"; fi
        exit $retval
      '';
    };
  };
}

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.vuizvui.services.starbound;

  mkListenerOptions = what: defaultPort: {
    bind = mkOption {
      type = types.str;
      default = "::";
      description = ''
        Host/IP address to listen for incoming connections to the ${what}.
      '';
    };

    port = mkOption {
      type = types.int;
      default = defaultPort;
      description = ''
        Port to listen for incoming connections to the ${what}.
      '';
    };
  };

  serverConfig = {
    allowAdminCommands = cfg.adminCommands.allow;
    allowAdminCommandsFromAnyone = cfg.adminCommands.allowFromAnyone;

    allowAnonymousConnections = cfg.anonymousConnections.allow;
    anonymousConnectionsAreAdmin = cfg.anonymousConnections.adminPrivileges;

    serverUsers = mapAttrs (user: attrs: {
      inherit (attrs) admin password;
    }) cfg.users;

    inherit (cfg) checkAssetsDigest clearPlayerFiles clearUniverseFiles;
    inherit (cfg) maxPlayers safeScripts serverName;
    inherit (cfg) upnpPortForwarding;

    gameServerBind = cfg.bind;
    gameServerPort = cfg.port;

    bannedIPs = cfg.bannedIPs;
    bannedUuids = cfg.bannedUUIDs;

    runRconServer = cfg.rconServer.enable;
    rconServerBind = cfg.rconServer.bind;
    rconServerPort = cfg.rconServer.port;
    rconServerPassword = cfg.rconServer.password;
    rconServerTimeout = cfg.rconServer.timeout;

    runQueryServer = cfg.queryServer.enable;
    queryServerBind = cfg.queryServer.bind;
    queryServerPort = cfg.queryServer.port;
  } // cfg.extraConfig;

  bootConfig = pkgs.runCommand "sbboot.config" {
    overrides = pkgs.writeText "sbboot.overrides" (builtins.toJSON {
      logFileBackups = 0;
      modSource = "";
      storageDirectory = cfg.dataDir;
      defaultConfiguration = serverConfig;
    });
  } ''
    "${pkgs.jq}/bin/jq" -s '.[0] * .[1]' \
      "${cfg.package}/etc/sbboot.config" "$overrides" \
      > "$out"
  '';

  # Traverse a given path with ../ until we get to the root directory (/).
  gotoRoot = p: concatStringsSep "/" (map (const "..") (splitString "/" p));

in {
  options.vuizvui.services.starbound = {
    enable = mkEnableOption "Starbound game server";

    adminCommands = {
      allow = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to allow admin commands in general.
        '';
        # XXX: Make this dependant on whether an account is defined with enabled
        # admin.
      };

      allowFromAnyone = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Allow anyone, even anonymous users to use admin commands.
        '';
        # XXX: Check whether this is true!
      };
    };

    anonymousConnections = {
      allow = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to allow anonymous connections to the server.

          Set this to <literal>false</literal> and use
          <option>serverUsers</option> to only allow specific accounts to
          connect.
        '';
      };

      adminPrivileges = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether all anonymous connections have administrative privileges.
        '';
      };
    };

    users = mkOption {
      type = types.attrsOf (types.submodule {
        options.admin = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether this user has admin privileges.
          '';
        };
        options.password = mkOption {
          type = types.str;
          example = "supersecure";
          description = ''
            The password for the user.
          '';
        };
      });
      default = {};
      description = ''
        User accounts to allow connection to the Starbound server.
      '';
    };

    checkAssetsDigest = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Check whether the assets on the client match the ones from the server
        and deny connection if they don't match.
      '';
    };

    clearPlayerFiles = mkOption {
      # XXX: Figure out the exact semantics of this.
      type = types.bool;
      default = false;
      description = ''
        Forces players to use new characters or to have no gear or tech.
      '';
    };

    clearUniverseFiles = mkOption {
      # XXX: Figure out the exact semantics of this.
      type = types.bool;
      default = false;
      description = ''
        Forces player characters to use fresh universe data and navigation maps.
      '';
    };

    bannedIPs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        IP addresses disallowed for connection to the server.
      '';
    };

    bannedUUIDs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        User IDs disallowed for connection to the server.
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/starbound";
      description = ''
        The directory where Starbound stores its universe/player files.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.vuizvui.games.humblebundle.starbound;
      defaultText = "pkgs.vuizvui.games.humblebundle.starbound";
      description = ''
        The starbound package to use for running this game server.
      '';
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Extra configuration options to add to the server config.
      '';
    };

    rconServer = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to run an RCON server which allows to run administrative
          commands on this game server instance.

          See the <link xlink:href="${
            "https://developer.valvesoftware.com/wiki/Source_RCON_Protocol"
          }">RCON protocol documentation</link> for more information about this.
        '';
      };

      password = mkOption {
        type = types.str;
        default = "";
        description = ''
          The password needed to authorize with the RCON server.
        '';
      };

      timeout = mkOption {
        type = types.int;
        default = 1000;
        # XXX: Find out what this timeout is for and whether it's in seconds.
        description = ''
          After how many seconds the RCON server drops the connection.
        '';
      };
    } // mkListenerOptions "RCON server" 21026;

    queryServer = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to run a query server that shows information such as currently
          connected players.
        '';
      };
    } // mkListenerOptions "query server" 21025;

    safeScripts = mkOption {
      type = types.bool;
      default = true;
      # XXX: The description is just a guess and we need to find out what this
      # really does.
      description = ''
        This is to make sure scripts can't call unsafe functions.
      '';
    };

    serverName = mkOption {
      type = types.str;
      default = "A Starbound Server";
      example = "My shiny Starbound Server";
      description = ''
        A short description or name of the Starbound server to run.
      '';
    };

    upnpPortForwarding = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to use UPnP to forward ports from NAT gateways.
      '';
    };

    maxPlayers = mkOption {
      type = types.int;
      default = 8;
      description = ''
        Maximum amount of players to allow concurrently.
      '';
    };
  } // mkListenerOptions "game server" 21025;

  config = mkIf cfg.enable {
    users.groups.starbound = {
      gid = config.ids.gids.starbound;
    };

    users.users.starbound = {
      uid = config.ids.uids.starbound;
      description = "Starbound Game Server User";
      group = "starbound";
      home = cfg.dataDir;
      createHome = true;
    };

    systemd.services.starbound = {
      description = "Starbound Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "fs.target" ];

      serviceConfig = {
        User = "starbound";
        Group = "starbound";
        PrivateTmp = true;

        KillSignal = "SIGINT";

        ExecStart = toString [
          "${cfg.package}/bin/starbound-server"
          "-bootconfig \"${bootConfig}\""
          # Workaround to disable logging to file
          "-logfile \"${gotoRoot cfg.dataDir}/dev/null\""
          "-verbose"
        ];
      };
    };
  };
}

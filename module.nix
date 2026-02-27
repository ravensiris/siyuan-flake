flake:
{ config, lib, pkgs, ... }:

let
  cfg = config.services.siyuan;
  settingsFormat = pkgs.formats.json { };
in
{
  options.services.siyuan = {
    enable = lib.mkEnableOption "SiYuan note-taking server";

    package = lib.mkPackageOption pkgs "siyuan" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6806;
      description = "Port for the SiYuan HTTP/WebSocket server.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Host address to bind the SiYuan server to.
        Use "0.0.0.0" to listen on all interfaces.
      '';
    };

    workspaceDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/siyuan/workspace";
      description = "Path to the SiYuan workspace directory.";
    };

    accessAuthCode = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Access authentication code for the SiYuan server.
        If empty, no authentication is required.

        WARNING: This value will be stored in the Nix store in plaintext.
        For sensitive deployments, consider using `accessAuthCodeFile` instead.
      '';
    };

    accessAuthCodeFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the access authentication code.
        The file should contain only the auth code with no trailing newline.
        This is preferred over `accessAuthCode` for security.
      '';
    };

    ssl = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable HTTPS and WSS.";
    };

    readOnly = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run SiYuan in read-only mode.";
    };

    lang = lib.mkOption {
      type = lib.types.enum [
        ""
        "ar_SA"
        "de_DE"
        "en_US"
        "es_ES"
        "fr_FR"
        "he_IL"
        "it_IT"
        "ja_JP"
        "ko_KR"
        "pl_PL"
        "pt_BR"
        "ru_RU"
        "tr_TR"
        "zh_CHT"
        "zh_CN"
      ];
      default = "";
      description = "Language for the SiYuan interface. Empty string uses the default.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "siyuan";
      description = "User under which the SiYuan server runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "siyuan";
      description = "Group under which the SiYuan server runs.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall port for SiYuan.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.accessAuthCode != "" && cfg.accessAuthCodeFile != null);
        message = "services.siyuan: accessAuthCode and accessAuthCodeFile are mutually exclusive.";
      }
    ];

    users.users.${cfg.user} = lib.mkIf (cfg.user == "siyuan") {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.workspaceDir;
      description = "SiYuan server user";
    };

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "siyuan") { };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.tmpfiles.rules = [
      "d ${cfg.workspaceDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.siyuan = {
      description = "SiYuan Note Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = cfg.workspaceDir;
        SIYUAN_WORKING_DIR = "${cfg.package}/share/siyuan/resources";
        RUN_IN_CONTAINER = "true";
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = "${cfg.package}/share/siyuan/resources";

        ExecStart = let
          kernel = "${cfg.package}/share/siyuan/resources/kernel/SiYuan-Kernel";
          args = lib.concatStringsSep " " (
            [
              "--port" (toString cfg.port)
              "--workspace" (toString cfg.workspaceDir)
              "--mode" "prod"
            ]
            ++ lib.optional (cfg.accessAuthCode != "")
              "--accessAuthCode ${cfg.accessAuthCode}"
            ++ lib.optional cfg.ssl "--ssl"
            ++ lib.optional cfg.readOnly "--readonly true"
            ++ lib.optional (cfg.lang != "") "--lang ${cfg.lang}"
          );
          # If accessAuthCodeFile is set, read the code from the file at runtime
          startScript = if cfg.accessAuthCodeFile != null then
            pkgs.writeShellScript "siyuan-start" ''
              AUTH_CODE=$(cat ${cfg.accessAuthCodeFile})
              exec ${kernel} \
                --port ${toString cfg.port} \
                --workspace ${toString cfg.workspaceDir} \
                --mode prod \
                ${lib.optionalString cfg.ssl "--ssl"} \
                ${lib.optionalString cfg.readOnly "--readonly true"} \
                ${lib.optionalString (cfg.lang != "") "--lang ${cfg.lang}"} \
                --accessAuthCode "$AUTH_CODE"
            ''
          else
            null;
        in
          if startScript != null
          then "${startScript}"
          else "${kernel} ${args}";

        Restart = "on-failure";
        RestartSec = 5;

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.workspaceDir ];
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        MemoryDenyWriteExecute = false; # SQLite needs this
      };
    };
  };
}

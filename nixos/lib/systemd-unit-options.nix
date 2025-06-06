{ lib, systemdUtils }:

let
  inherit (systemdUtils.lib)
    assertValueOneOf
    automountConfig
    checkUnitConfig
    makeJobScript
    mountConfig
    serviceConfig
    unitConfig
    unitNameType
    ;

  inherit (lib)
    any
    concatMap
    isList
    literalExpression
    mergeEqualOption
    mkIf
    mkMerge
    mkOption
    mkOptionType
    singleton
    toList
    types
    ;

  checkService = checkUnitConfig "Service" [
    (assertValueOneOf "Type" [
      "exec"
      "simple"
      "forking"
      "oneshot"
      "dbus"
      "notify"
      "notify-reload"
      "idle"
    ])
    (assertValueOneOf "Restart" [
      "no"
      "on-success"
      "on-failure"
      "on-abnormal"
      "on-abort"
      "always"
    ])
  ];

in
rec {

  unitOption = mkOptionType {
    name = "systemd option";
    merge =
      loc: defs:
      if any (def: isList def.value) defs then
        concatMap (def: toList def.value) defs
      else
        mergeEqualOption loc defs;
  };

  sharedOptions = {

    enable = mkOption {
      default = true;
      type = types.bool;
      description = ''
        If set to false, this unit will be a symlink to
        /dev/null. This is primarily useful to prevent specific
        template instances
        (e.g. `serial-getty@ttyS0`) from being
        started. Note that `enable=true` does not
        make a unit start by default at boot; if you want that, see
        `wantedBy`.
      '';
    };

    name = lib.mkOption {
      type = lib.types.str;
      description = ''
        The name of this systemd unit, including its extension.
        This can be used to refer to this unit from other systemd units.
      '';
    };

    overrideStrategy = mkOption {
      default = "asDropinIfExists";
      type = types.enum [
        "asDropinIfExists"
        "asDropin"
      ];
      description = ''
        Defines how unit configuration is provided for systemd:

        `asDropinIfExists` creates a unit file when no unit file is provided by the package
        otherwise it creates a drop-in file named `overrides.conf`.

        `asDropin` creates a drop-in file named `overrides.conf`.
        Mainly needed to define instances for systemd template units (e.g. `systemd-nspawn@mycontainer.service`).

        See also {manpage}`systemd.unit(5)`.
      '';
    };

    requiredBy = mkOption {
      default = [ ];
      type = types.listOf unitNameType;
      description = ''
        Units that require (i.e. depend on and need to go down with) this unit.
        As discussed in the `wantedBy` option description this also creates
        `.requires` symlinks automatically.
      '';
    };

    upheldBy = mkOption {
      default = [ ];
      type = types.listOf unitNameType;
      description = ''
        Keep this unit running as long as the listed units are running. This is a continuously
        enforced version of wantedBy.
      '';
    };

    wantedBy = mkOption {
      default = [ ];
      type = types.listOf unitNameType;
      description = ''
        Units that want (i.e. depend on) this unit. The default method for
        starting a unit by default at boot time is to set this option to
        `["multi-user.target"]` for system services. Likewise for user units
        (`systemd.user.<name>.*`) set it to `["default.target"]` to make a unit
        start by default when the user `<name>` logs on.

        This option creates a `.wants` symlink in the given target that exists
        statelessly without the need for running `systemctl enable`.
        The `[Install]` section described in {manpage}`systemd.unit(5)` however is
        not supported because it is a stateful process that does not fit well
        into the NixOS design.
      '';
    };

    aliases = mkOption {
      default = [ ];
      type = types.listOf unitNameType;
      description = "Aliases of that unit.";
    };

  };

  concreteUnitOptions = sharedOptions // {

    text = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Text of this systemd unit.";
    };

    unit = mkOption {
      internal = true;
      description = "The generated unit.";
    };

  };

  commonUnitOptions = {
    options = sharedOptions // {

      description = mkOption {
        default = "";
        type = types.singleLineStr;
        description = "Description of this unit used in systemd messages and progress indicators.";
      };

      documentation = mkOption {
        default = [ ];
        type = types.listOf types.str;
        description = "A list of URIs referencing documentation for this unit or its configuration.";
      };

      requires = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          Start the specified units when this unit is started, and stop
          this unit when the specified units are stopped or fail.
        '';
      };

      wants = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          Start the specified units when this unit is started.
        '';
      };

      upholds = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          Keeps the specified running while this unit is running. A continuous version of `wants`.
        '';
      };

      after = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          If the specified units are started at the same time as
          this unit, delay this unit until they have started.
        '';
      };

      before = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          If the specified units are started at the same time as
          this unit, delay them until this unit has started.
        '';
      };

      bindsTo = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          Like ‘requires’, but in addition, if the specified units
          unexpectedly disappear, this unit will be stopped as well.
        '';
      };

      partOf = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          If the specified units are stopped or restarted, then this
          unit is stopped or restarted as well.
        '';
      };

      conflicts = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          If the specified units are started, then this unit is stopped
          and vice versa.
        '';
      };

      requisite = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          Similar to requires. However if the units listed are not started,
          they will not be started and the transaction will fail.
        '';
      };

      unitConfig = mkOption {
        default = { };
        example = {
          RequiresMountsFor = "/data";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Unit]` section of the unit.  See
          {manpage}`systemd.unit(5)` for details.
        '';
      };

      onFailure = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          A list of one or more units that are activated when
          this unit enters the "failed" state.
        '';
      };

      onSuccess = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          A list of one or more units that are activated when
          this unit enters the "inactive" state.
        '';
      };

      startLimitBurst = mkOption {
        type = types.int;
        description = ''
          Configure unit start rate limiting. Units which are started
          more than startLimitBurst times within an interval time
          interval are not permitted to start any more.
        '';
      };

      startLimitIntervalSec = mkOption {
        type = types.int;
        description = ''
          Configure unit start rate limiting. Units which are started
          more than startLimitBurst times within an interval time
          interval are not permitted to start any more.
        '';
      };

    };
  };

  stage2CommonUnitOptions = {
    imports = [
      commonUnitOptions
    ];

    options = {
      restartTriggers = mkOption {
        default = [ ];
        type = types.listOf types.unspecified;
        description = ''
          An arbitrary list of items such as derivations.  If any item
          in the list changes between reconfigurations, the service will
          be restarted.
        '';
      };

      reloadTriggers = mkOption {
        default = [ ];
        type = types.listOf unitOption;
        description = ''
          An arbitrary list of items such as derivations.  If any item
          in the list changes between reconfigurations, the service will
          be reloaded.  If anything but a reload trigger changes in the
          unit file, the unit will be restarted instead.
        '';
      };
    };
  };
  stage1CommonUnitOptions = commonUnitOptions;

  serviceOptions =
    { name, config, ... }:
    {
      options = {

        environment = mkOption {
          default = { };
          type =
            with types;
            attrsOf (
              nullOr (oneOf [
                str
                path
                package
              ])
            );
          example = {
            PATH = "/foo/bar/bin";
            LANG = "nl_NL.UTF-8";
          };
          description = "Environment variables passed to the service's processes.";
        };

        path = mkOption {
          default = [ ];
          type =
            with types;
            listOf (oneOf [
              package
              str
            ]);
          description = ''
            Packages added to the service's {env}`PATH`
            environment variable.  Both the {file}`bin`
            and {file}`sbin` subdirectories of each
            package are added.
          '';
        };

        serviceConfig = mkOption {
          default = { };
          example = {
            RestartSec = 5;
          };
          type = types.addCheck (types.attrsOf unitOption) checkService;
          description = ''
            Each attribute in this set specifies an option in the
            `[Service]` section of the unit.  See
            {manpage}`systemd.service(5)` for details.
          '';
        };

        enableStrictShellChecks = mkOption {
          type = types.bool;
          description = ''
            Enable running `shellcheck` on the generated scripts for this unit.

            When enabled, scripts generated by the unit will be checked with
            `shellcheck` and any errors or warnings will cause the build to
            fail.

            This affects all scripts that have been created through the
            `script`, `reload`, `preStart`, `postStart`, `preStop` and
            `postStop` options for systemd services. This does not affect
            command lines passed directly to `ExecStart`, `ExecReload`,
            `ExecStartPre`, `ExecStartPost`, `ExecStop` or `ExecStopPost`.
          '';
          # The default gets set in systemd-lib.nix because we don't have
          # access to the full NixOS config here.
          defaultText = literalExpression "config.systemd.enableStrictShellChecks";
        };

        script = mkOption {
          type = types.lines;
          default = "";
          description = "Shell commands executed as the service's main process.";
        };

        scriptArgs = mkOption {
          type = types.str;
          default = "";
          example = "%i";
          description = ''
            Arguments passed to the main process script.
            Can contain specifiers (`%` placeholders expanded by systemd, see {manpage}`systemd.unit(5)`).
          '';
        };

        preStart = mkOption {
          type = types.lines;
          default = "";
          description = ''
            Shell commands executed before the service's main process
            is started.
          '';
        };

        postStart = mkOption {
          type = types.lines;
          default = "";
          description = ''
            Shell commands executed after the service's main process
            is started.
          '';
        };

        reload = mkOption {
          type = types.lines;
          default = "";
          description = ''
            Shell commands executed when the service's main process
            is reloaded.
          '';
        };

        preStop = mkOption {
          type = types.lines;
          default = "";
          description = ''
            Shell commands executed to stop the service.
          '';
        };

        postStop = mkOption {
          type = types.lines;
          default = "";
          description = ''
            Shell commands executed after the service's main process
            has exited.
          '';
        };

        jobScripts = mkOption {
          type = with types; coercedTo path singleton (listOf path);
          internal = true;
          description = "A list of all job script derivations of this unit.";
          default = [ ];
        };

      };

      config = mkMerge [
        (mkIf (config.preStart != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-pre-start";
            text = config.preStart;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecStartPre = [ jobScripts ];
        })
        (mkIf (config.script != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-start";
            text = config.script;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecStart = jobScripts + " " + config.scriptArgs;
        })
        (mkIf (config.postStart != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-post-start";
            text = config.postStart;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecStartPost = [ jobScripts ];
        })
        (mkIf (config.reload != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-reload";
            text = config.reload;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecReload = jobScripts;
        })
        (mkIf (config.preStop != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-pre-stop";
            text = config.preStop;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecStop = jobScripts;
        })
        (mkIf (config.postStop != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-post-stop";
            text = config.postStop;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecStopPost = jobScripts;
        })
      ];

    };

  stage2ServiceOptions = {
    imports = [
      stage2CommonUnitOptions
      serviceOptions
    ];

    options = {
      restartIfChanged = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether the service should be restarted during a NixOS
          configuration switch if its definition has changed.
        '';
      };

      reloadIfChanged = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether the service should be reloaded during a NixOS
          configuration switch if its definition has changed.  If
          enabled, the value of {option}`restartIfChanged` is
          ignored.

          This option should not be used anymore in favor of
          {option}`reloadTriggers` which allows more granular
          control of when a service is reloaded and when a service
          is restarted.
        '';
      };

      stopIfChanged = mkOption {
        type = types.bool;
        default = true;
        description = ''
          If set, a changed unit is restarted by calling
          {command}`systemctl stop` in the old configuration,
          then {command}`systemctl start` in the new one.
          Otherwise, it is restarted in a single step using
          {command}`systemctl restart` in the new configuration.
          The latter is less correct because it runs the
          `ExecStop` commands from the new
          configuration.
        '';
      };

      notSocketActivated = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If set, a changed unit is never assumed to be
          socket-activated on configuration switch, even if
          it might have associated socket units. Instead, the unit
          will be restarted (or stopped/started) as if it had no
          associated sockets.
        '';
      };

      startAt = mkOption {
        type = with types; either str (listOf str);
        default = [ ];
        example = "Sun 14:00:00";
        description = ''
          Automatically start this unit at the given date/time, which
          must be in the format described in
          {manpage}`systemd.time(7)`.  This is equivalent
          to adding a corresponding timer unit with
          {option}`OnCalendar` set to the value given here.
        '';
        apply = v: if isList v then v else [ v ];
      };
    };
  };

  stage1ServiceOptions = {
    imports = [
      stage1CommonUnitOptions
      serviceOptions
    ];
  };

  socketOptions = {
    options = {

      listenStreams = mkOption {
        default = [ ];
        type = types.listOf types.str;
        example = [
          "0.0.0.0:993"
          "/run/my-socket"
        ];
        description = ''
          For each item in this list, a `ListenStream`
          option in the `[Socket]` section will be created.
        '';
      };

      listenDatagrams = mkOption {
        default = [ ];
        type = types.listOf types.str;
        example = [
          "0.0.0.0:993"
          "/run/my-socket"
        ];
        description = ''
          For each item in this list, a `ListenDatagram`
          option in the `[Socket]` section will be created.
        '';
      };

      socketConfig = mkOption {
        default = { };
        example = {
          ListenStream = "/run/my-socket";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Socket]` section of the unit.  See
          {manpage}`systemd.socket(5)` for details.
        '';
      };
    };

  };

  stage2SocketOptions = {
    imports = [
      stage2CommonUnitOptions
      socketOptions
    ];
  };

  stage1SocketOptions = {
    imports = [
      stage1CommonUnitOptions
      socketOptions
    ];
  };

  timerOptions = {
    options = {

      timerConfig = mkOption {
        default = { };
        example = {
          OnCalendar = "Sun 14:00:00";
          Unit = "foo.service";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Timer]` section of the unit.  See
          {manpage}`systemd.timer(5)` and
          {manpage}`systemd.time(7)` for details.
        '';
      };

    };
  };

  stage2TimerOptions = {
    imports = [
      stage2CommonUnitOptions
      timerOptions
    ];
  };

  stage1TimerOptions = {
    imports = [
      stage1CommonUnitOptions
      timerOptions
    ];
  };

  pathOptions = {
    options = {

      pathConfig = mkOption {
        default = { };
        example = {
          PathChanged = "/some/path";
          Unit = "changedpath.service";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Path]` section of the unit.  See
          {manpage}`systemd.path(5)` for details.
        '';
      };

    };
  };

  stage2PathOptions = {
    imports = [
      stage2CommonUnitOptions
      pathOptions
    ];
  };

  stage1PathOptions = {
    imports = [
      stage1CommonUnitOptions
      pathOptions
    ];
  };

  mountOptions = {
    options = {

      what = mkOption {
        example = "/dev/sda1";
        type = types.str;
        description = "Absolute path of device node, file or other resource. (Mandatory)";
      };

      where = mkOption {
        example = "/mnt";
        type = types.str;
        description = ''
          Absolute path of a directory of the mount point.
          Will be created if it doesn't exist. (Mandatory)
        '';
      };

      type = mkOption {
        default = "";
        example = "ext4";
        type = types.str;
        description = "File system type.";
      };

      options = mkOption {
        default = "";
        example = "noatime";
        type = types.commas;
        description = "Options used to mount the file system.";
      };

      mountConfig = mkOption {
        default = { };
        example = {
          DirectoryMode = "0775";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Mount]` section of the unit.  See
          {manpage}`systemd.mount(5)` for details.
        '';
      };

    };
  };

  stage2MountOptions = {
    imports = [
      stage2CommonUnitOptions
      mountOptions
    ];
  };

  stage1MountOptions = {
    imports = [
      stage1CommonUnitOptions
      mountOptions
    ];
  };

  automountOptions = {
    options = {

      where = mkOption {
        example = "/mnt";
        type = types.str;
        description = ''
          Absolute path of a directory of the mount point.
          Will be created if it doesn't exist. (Mandatory)
        '';
      };

      automountConfig = mkOption {
        default = { };
        example = {
          DirectoryMode = "0775";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Automount]` section of the unit.  See
          {manpage}`systemd.automount(5)` for details.
        '';
      };

    };
  };

  stage2AutomountOptions = {
    imports = [
      stage2CommonUnitOptions
      automountOptions
    ];
  };

  stage1AutomountOptions = {
    imports = [
      stage1CommonUnitOptions
      automountOptions
    ];
  };

  sliceOptions = {
    options = {

      sliceConfig = mkOption {
        default = { };
        example = {
          MemoryMax = "2G";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Slice]` section of the unit.  See
          {manpage}`systemd.slice(5)` for details.
        '';
      };

    };
  };

  stage2SliceOptions = {
    imports = [
      stage2CommonUnitOptions
      sliceOptions
    ];
  };

  stage1SliceOptions = {
    imports = [
      stage1CommonUnitOptions
      sliceOptions
    ];
  };

}

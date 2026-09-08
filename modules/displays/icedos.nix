{ icedosLib, ... }:
{
  outputs.nixosModules =
    { ... }:
    [
      (
        {
          config,
          lib,
          pkgs,
          ...
        }:

        let
          inherit (lib)
            head
            length
            mkIf
            optional
            optionals
            ;

          inherit (config.icedos) hardware;

          gnome = icedosLib.hasModule {
            inherit config;
            url = "github:icedos/gnome";
            modules = [ "default" ];
          };

          hyprland = icedosLib.hasModule {
            inherit config;
            url = "github:icedos/hyprland";
            modules = [ "default" ];
          };

          # /tmp is world-writable (pre-create/symlink clobber risk); use the
          # 0700 XDG_RUNTIME_DIR, else the user cache. `\$` keeps it literal.
          tempConfigPath = "\${XDG_RUNTIME_DIR:-$HOME/.cache}/icedos";
          primaryDisplayPath = "${tempConfigPath}/primary-display";
        in
        {
          icedos.system.toolset.commands = mkIf (gnome || hyprland) [
            {
              command = "displays";
              help = "print displays related commands";
              commands = [
                {
                  command = "info";
                  help = "print displays information";
                  script = ''
                    ${
                      if gnome then
                        ''[ "$XDG_CURRENT_DESKTOP" = "GNOME" ] && "${pkgs.gnome-randr}/bin/gnome-randr"''
                      else
                        ""
                    }

                    ${
                      if hyprland then
                        ''[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ] && "${pkgs.hyprland}/bin/hyprctl" monitors''
                      else
                        ""
                    }
                  '';
                }
              ]
              ++ optional hyprland {
                command = "xprimary";
                help = "set primary monitor for xwayland";
                script = ''
                  [ "$XDG_CURRENT_DESKTOP" = "GNOME" ] && echo "error: not supported by gnome" && exit 1

                  ACTIVE_MONITORS=($(${pkgs.xorg.xrandr}/bin/xrandr --listactivemonitors | ${pkgs.gnugrep}/bin/grep '+0' | ${pkgs.gawk}/bin/awk '{ print $4 }' | ${pkgs.coreutils}/bin/sort))
                  TEMP_CONFIG_PATH="${tempConfigPath}"
                  PRIMARY_DISPLAY_PATH="${primaryDisplayPath}"

                  ${pkgs.coreutils}/bin/mkdir -p "$TEMP_CONFIG_PATH"
                  echo "Select a display:"

                  select monitor in "''${ACTIVE_MONITORS[@]}"; do
                    [ "$monitor" != "" ] && echo "$monitor" > "$PRIMARY_DISPLAY_PATH" && exit 0
                    echo "error: not a valid selection, try again"
                  done
                '';
              };
            }
          ];

          icedos.system.tips.list =
            optionals (gnome || hyprland) [
              "icedos displays info lists your monitors with their resolution and refresh rate."
            ]
            ++ optionals hyprland [
              "icedos displays xprimary picks the monitor older X11 apps treat as the main one."
            ];

          home-manager.sharedModules = [
            {
              systemd.user.services.xprimary =
                mkIf
                  (
                    hyprland
                    && icedosLib.hasModule {
                      inherit config;
                      url = "github:icedos/hardware";
                      name = "monitors";
                    }
                    && (length hardware.monitors) != 0
                  )
                  {

                    Unit = {
                      Description = "X11 primary display watcher";
                      StartLimitIntervalSec = 60;
                      StartLimitBurst = 60;
                    };

                    Install.WantedBy = [
                      "graphical-session.target"
                      "hyprland-session.target"
                    ];

                    Service = {
                      ExecStart =
                        let
                          coreutils = pkgs.coreutils-full;
                          echo = "${coreutils}/bin/echo";
                          xrandr = "${pkgs.xorg.xrandr}/bin/xrandr";
                        in
                        "${pkgs.writeShellScript "xprimary" ''
                          TEMP_CONFIG_PATH="${tempConfigPath}"
                          PRIMARY_DISPLAY_PATH="${primaryDisplayPath}"
                          PRIMARY_DISPLAY="${(head hardware.monitors).name}"

                          function setPrimaryMonitor () {
                            ${echo} "$1" > "$PRIMARY_DISPLAY_PATH"
                            ${xrandr} --output "$1" --primary || exit 1
                            ${pkgs.libnotify}/bin/notify-send "System" "Set X11 primary display to $1"
                            ${echo} "Set X11 primary display to $PRIMARY_DISPLAY"
                          }

                          ${coreutils}/bin/mkdir -p "$TEMP_CONFIG_PATH"
                          setPrimaryMonitor "$PRIMARY_DISPLAY"

                          while :; do
                            ${coreutils}/bin/sleep 1

                            CURRENT_PRIMARY_DISPLAY="$PRIMARY_DISPLAY"
                            [ -f "$PRIMARY_DISPLAY_PATH" ] && CURRENT_PRIMARY_DISPLAY=$(${coreutils}/bin/cat "$PRIMARY_DISPLAY_PATH")

                            # State file is user-writable (untrusted): guard the
                            # name before xrandr, keep the last good primary.
                            [[ "$CURRENT_PRIMARY_DISPLAY" =~ ^[A-Za-z0-9.-]+$ ]] || {
                              ${echo} "xprimary: ignoring invalid monitor name '$CURRENT_PRIMARY_DISPLAY'" >&2
                              CURRENT_PRIMARY_DISPLAY="$PRIMARY_DISPLAY"
                            }

                            [[ "$CURRENT_PRIMARY_DISPLAY" == "$PRIMARY_DISPLAY" && "$(${xrandr} --current | ${pkgs.gnugrep}/bin/grep primary | ${pkgs.gawk}/bin/awk '{print $1}')" == "$CURRENT_PRIMARY_DISPLAY" ]] && continue

                            PRIMARY_DISPLAY="$CURRENT_PRIMARY_DISPLAY"
                            setPrimaryMonitor "$PRIMARY_DISPLAY"
                          done
                        ''}";

                      Restart = "on-failure";
                    };
                  };
            }
          ];
        }
      )
    ];

  meta.name = "displays";
}

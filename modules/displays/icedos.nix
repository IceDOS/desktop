{ ... }:
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
            hasAttr
            head
            length
            mkIf
            optional
            ;

          inherit (config.icedos) desktop hardware;

          gnome = hasAttr "gnome" desktop;
          hyprland = hasAttr "hyprland" desktop;

          # Per-user state: /tmp is world-writable and shared across users, so
          # a local process could pre-create the path / symlink the file and
          # the xprimary service's `echo >` would clobber it (and two logged-in
          # users would fight over the same file). XDG_RUNTIME_DIR is a 0700
          # per-user tmpfs; fall back to the user cache when unset. The `\$`
          # escape keeps the shell parameter expansion literal so both the
          # toolset command and the systemd service expand the same path at
          # runtime.
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

          home-manager.sharedModules = [
            {
              systemd.user.services.xprimary =
                mkIf (hyprland && hasAttr "monitors" hardware && (length hardware.monitors) != 0)
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

                            # The state file is user-writable, so the name is
                            # untrusted — guard it before it can reach xrandr
                            # and keep the last good primary on mismatch.
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

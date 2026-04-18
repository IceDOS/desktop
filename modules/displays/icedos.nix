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
            mapAttrs
            mkIf
            optional
            ;

          cfg = config.icedos;
          gnome = hasAttr "gnome" cfg.desktop;
          hyprland = hasAttr "hyprland" cfg.desktop;
          tempConfigPath = "/tmp/icedos";
          primaryDisplayPath = "${tempConfigPath}/primary-display";
        in
        {
          icedos.applications.toolset.commands = mkIf (gnome || hyprland) [
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

                  ACTIVE_MONITORS=($(xrandr --listactivemonitors | grep '+0' | awk '{ print $4 }' | sort))
                  TEMP_CONFIG_PATH="${tempConfigPath}"
                  PRIMARY_DISPLAY_PATH="${primaryDisplayPath}"

                  mkdir -p "$TEMP_CONFIG_PATH"
                  echo "Select a display:"

                  select monitor in "''${ACTIVE_MONITORS[@]}"; do
                    [ "$monitor" != "" ] && echo "$monitor" > "$PRIMARY_DISPLAY_PATH" && exit 0
                    echo "error: not a valid selection, try again"
                  done
                '';
              };
            }
          ];

          home-manager.users = mapAttrs (user: _: {
            systemd.user.services.xprimary =
              mkIf (hyprland && hasAttr "monitors" cfg.hardware && (length cfg.hardware.monitors) != 0)
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
                        PRIMARY_DISPLAY="${(head (cfg.hardware.monitors)).name}"

                        function setPrimaryMonitor () {
                          ${echo} "$1" > "$PRIMARY_DISPLAY_PATH"
                          ${xrandr} --output "$1" --primary || exit 1
                          ${pkgs.libnotify}/bin/notify-send "System" "Set X11 primary display to $1"
                          ${echo} "Set X11 primary display to $PRIMARY_DISPLAY"
                        }

                        setPrimaryMonitor "$PRIMARY_DISPLAY"

                        while :; do
                          ${coreutils}/bin/sleep 1
                          ${coreutils}/bin/mkdir -p "$TEMP_CONFIG_PATH"

                          CURRENT_PRIMARY_DISPLAY="$PRIMARY_DISPLAY"
                          [ -f "$PRIMARY_DISPLAY_PATH" ] && CURRENT_PRIMARY_DISPLAY=$(${coreutils}/bin/cat "$PRIMARY_DISPLAY_PATH")

                          [[ "$CURRENT_PRIMARY_DISPLAY" == "$PRIMARY_DISPLAY" && "$(${xrandr} --current | ${pkgs.gnugrep}/bin/grep primary | ${pkgs.gawk}/bin/awk '{print $1}')" == "$CURRENT_PRIMARY_DISPLAY" ]] && continue

                          PRIMARY_DISPLAY="$CURRENT_PRIMARY_DISPLAY"
                          setPrimaryMonitor "$PRIMARY_DISPLAY"
                        done
                      ''}";

                    Nice = "-20";
                    Restart = "on-failure";
                  };
                };
          }) cfg.users;
        }
      )
    ];

  meta.name = "displays";
}

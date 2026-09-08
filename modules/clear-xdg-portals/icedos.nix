{ ... }:
{
  outputs.nixosModules =
    { ... }:
    [
      (
        {
          pkgs,
          ...
        }:

        {
          icedos.system.toolset.commands = [
            {
              command = "clear-portals";

              script = ''
                PORTAL="xdg-desktop-portal"

                log_step "Clearing xdg desktop portal state..."

                ${pkgs.coreutils}/bin/rm -rf -- "$HOME/.config/$PORTAL"
                ${pkgs.coreutils}/bin/rm -rf -- "$HOME/.cache/$PORTAL"

                # System dirs need the setuid wrapper (a store-path binary is
                # not setuid); guard so deletions no-op when absent.
                for dir in "/etc/xdg/$PORTAL" "/usr/share/$PORTAL"; do
                  if [ -e "$dir" ]; then
                    log_warn "removing system portal directory $dir (sudo)"
                    /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/rm -rf -- "$dir"
                  fi
                done

                log_ok "cleared xdg portal files"
              '';

              help = "remove all xdg portal files, useful if portals are malfunctioning";
            }
          ];

          icedos.system.tips.list = [
            "Run icedos clear-portals when file pickers or screen sharing misbehave."
          ];
        }
      )
    ];

  meta.name = "clear-xdg-portals";
}

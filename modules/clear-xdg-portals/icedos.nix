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

                # System-wide dirs need the setuid wrapper (a store-path sudo
                # binary is not setuid). Guard with an existence check so the
                # deletions no-op cleanly when absent (e.g. /usr/share/... does
                # not exist on stock NixOS).
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
        }
      )
    ];

  meta.name = "clear-xdg-portals";
}

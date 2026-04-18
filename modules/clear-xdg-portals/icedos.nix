{ ... }:
{
  outputs.nixosModules =
    { ... }:
    [
      {
        icedos.applications.toolset.commands = [
          {
            command = "clear-portals";

            script = ''
              PORTAL="xdg-desktop-portal"

              rm -rf "$HOME/.config/$PORTAL"
              rm -rf "$HOME/.cache/$PORTAL"
              sudo rm -rf "/etc/xdg/$PORTAL"
              sudo rm -rf "/usr/share/$PORTAL"
            '';

            help = "remove all xdg portal files, useful if portals are malfunctioning";
          }
        ];
      }
    ];

  meta.name = "clear-xdg-portals";
}

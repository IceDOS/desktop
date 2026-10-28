{ icedosLib, lib, ... }:

{
  options.icedos.desktop.applications =
    let
      inherit (icedosLib) mkStrOption;
      inherit ((lib.importTOML ./config.toml).icedos.desktop) applications;
    in
    {
      audio-player = {
        package = mkStrOption { default = applications.audio-player.package; };
        name = mkStrOption { default = applications.audio-player.name; };
      };

      browser = {
        package = mkStrOption { default = applications.browser.package; };
        name = mkStrOption { default = applications.browser.name; };
      };

      editor = {
        package = mkStrOption { default = applications.editor.package; };
        name = mkStrOption { default = applications.editor.name; };
      };

      files = {
        package = mkStrOption { default = applications.files.package; };
        name = mkStrOption { default = applications.files.name; };
      };

      archive-manager = {
        package = mkStrOption { default = applications.archive-manager.package; };
        name = mkStrOption { default = applications.archive-manager.name; };
      };

      image-viewer = {
        package = mkStrOption { default = applications.image-viewer.package; };
        name = mkStrOption { default = applications.image-viewer.name; };
      };

      office-suite = {
        package = mkStrOption { default = applications.office-suite.package; };
        name = mkStrOption { default = applications.office-suite.name; };
      };

      torrent = {
        package = mkStrOption { default = applications.torrent.package; };
        name = mkStrOption { default = applications.torrent.name; };
      };

      video-player = {
        package = mkStrOption { default = applications.video-player.package; };
        name = mkStrOption { default = applications.video-player.name; };
      };

      wine = {
        package = mkStrOption { default = applications.wine.package; };
        name = mkStrOption { default = applications.wine.name; };
      };
    };

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
            filter
            attrValues
            listToAttrs
            mkIf
            nameValuePair
            ;

          inherit (config.icedos.desktop) applications;

          # Mime-wire on desktop-id alone; the package may be installed by the app's own module.
          nameOf = app: mkIf (app.name != "") app.name;

          # `name` is a key under icedos.desktop.applications.
          mkMimeDefaults =
            entries:
            listToAttrs (map ({ type, name }: nameValuePair type (nameOf applications.${name})) entries);
        in
        {
          icedos.system.tips.list = [
            "Your default apps for video, music, images and documents are set under [icedos.desktop.applications]."
          ];

          # Install every mime-default app; any new option under
          # `icedos.desktop.applications.*` is auto-hooked (packages resolved via icedosLib).
          environment.systemPackages = icedosLib.pkgs.mapper pkgs (
            map (app: app.package) (filter (app: app.package != "") (attrValues applications))
          );

          xdg.mime = {
            enable = true;

            defaultApplications = mkMimeDefaults [
              {
                type = "application/json";
                name = "editor";
              }
              {
                type = "application/msword";
                name = "office-suite";
              }
              {
                type = "application/oxps";
                name = "office-suite";
              }
              {
                type = "application/pdf";
                name = "browser";
              }
              {
                type = "application/rtf";
                name = "office-suite";
              }
              {
                type = "application/vnd.ms-excel";
                name = "office-suite";
              }
              {
                type = "application/vnd.ms-powerpoint";
                name = "office-suite";
              }
              {
                type = "application/vnd.ms-xpsdocument";
                name = "office-suite";
              }
              {
                type = "application/vnd.oasis.opendocument.presentation";
                name = "office-suite";
              }
              {
                type = "application/vnd.oasis.opendocument.presentation-template";
                name = "office-suite";
              }
              {
                type = "application/vnd.oasis.opendocument.spreadsheet";
                name = "office-suite";
              }
              {
                type = "application/vnd.oasis.opendocument.spreadsheet-template";
                name = "office-suite";
              }
              {
                type = "application/vnd.oasis.opendocument.text";
                name = "office-suite";
              }
              {
                type = "application/vnd.oasis.opendocument.text-template";
                name = "office-suite";
              }
              {
                type = "application/vnd.openxmlformats-officedocument.presentationml.presentation";
                name = "office-suite";
              }
              {
                type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
                name = "office-suite";
              }
              {
                type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
                name = "office-suite";
              }
              {
                type = "application/x-bittorrent";
                name = "torrent";
              }
              {
                type = "application/x-ms-dos-executable";
                name = "wine";
              }
              {
                type = "application/x-shellscript";
                name = "editor";
              }
              {
                type = "application/x-wine-extension-ini";
                name = "editor";
              }
              {
                type = "application/x-zerosize";
                name = "editor";
              }
              {
                type = "application/xhtml_xml";
                name = "browser";
              }
              {
                type = "application/xhtml+xml";
                name = "browser";
              }
              {
                type = "application/zip";
                name = "archive-manager";
              }
              {
                type = "audio/aac";
                name = "audio-player";
              }
              {
                type = "audio/flac";
                name = "audio-player";
              }
              {
                type = "audio/m4a";
                name = "audio-player";
              }
              {
                type = "audio/mp3";
                name = "audio-player";
              }
              {
                type = "audio/wav";
                name = "audio-player";
              }
              {
                type = "image/avif";
                name = "image-viewer";
              }
              {
                type = "image/bmp";
                name = "image-viewer";
              }
              {
                type = "image/gif";
                name = "image-viewer";
              }
              {
                type = "image/heic";
                name = "image-viewer";
              }
              {
                type = "image/heif";
                name = "image-viewer";
              }
              {
                type = "image/jpeg";
                name = "image-viewer";
              }
              {
                type = "image/jxl";
                name = "image-viewer";
              }
              {
                type = "image/png";
                name = "image-viewer";
              }
              {
                type = "image/svg+xml";
                name = "image-viewer";
              }
              {
                type = "image/tiff";
                name = "image-viewer";
              }
              {
                type = "image/vnd.microsoft.icon";
                name = "image-viewer";
              }
              {
                type = "image/webp";
                name = "image-viewer";
              }
              {
                type = "inode/directory";
                name = "files";
              }
              {
                type = "text/csv";
                name = "office-suite";
              }
              {
                type = "text/html";
                name = "browser";
              }
              {
                type = "text/plain";
                name = "editor";
              }
              {
                type = "text/tab-separated-values";
                name = "office-suite";
              }
              {
                type = "video/mp4";
                name = "video-player";
              }
              {
                type = "video/quicktime";
                name = "video-player";
              }
              {
                type = "video/x-matroska";
                name = "video-player";
              }
              {
                type = "video/x-ms-wmv";
                name = "video-player";
              }
              {
                type = "x-scheme-handler/about";
                name = "browser";
              }
              {
                type = "x-scheme-handler/http";
                name = "browser";
              }
              {
                type = "x-scheme-handler/https";
                name = "browser";
              }
              {
                type = "x-scheme-handler/unknown";
                name = "browser";
              }
              {
                type = "x-www-browser";
                name = "browser";
              }
            ];
          };
        }
      )
    ];

  meta.name = "applications";
}

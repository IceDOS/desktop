# AGENTS.md — IceDOS **desktop**

> Utilizes the **IceDOS** framework. The full bible — module structure, config flow,
> the `icedos rebuild --build` test loop, `validate.*` helpers, dep loading — lives in
> **core**: <https://github.com/IceDOS/core/blob/main/AGENTS.md> — this file only
> covers what is specific to **desktop**.

## Non-negotiable rules (full detail in core)
- Build/test only via the `icedos` CLI — **never `sudo nixos-rebuild`**.
- **Never** `git commit/stash/reset/pull` — the user manages git.
- Every option uses a `validate.*`/`mk*Option` helper; **no untyped options**.
- A module's `config.toml` defaults must mirror its `icedos.nix` defaults.
- Format with `icedos nixf .` after editing any `.nix`.
- If a repo or the config root you need isn't checked out locally, **ask the user** for
  its path or permission to `git clone` it — don't guess or clone unprompted.

## Purpose
Cross-desktop glue shared by every DE (GNOME/Hyprland/KDE/COSMIC): display manager,
theming, displays, portals, desktop entries, session/startup. The `icedos.desktop.*`
namespace that is **not** specific to one DE lives here.

## Layout
`modules/<name>/{icedos.nix,config.toml}` per module; `flake.nix` exposes them via
`icedosLib.scanModules { path = ./modules; filename = "icedos.nix"; }`.

The repo also ships a repo-root **`lib.nix`** — the desktop/DE-dependent helpers
(accent resolution, button-layout string, per-DE session targets). The always-on
`default` module imports it through its top-level `lib` field
(`modules/default/icedos.nix`: `lib = import ../../lib.nix { inherit icedosLib lib; };`),
and core merges that field into the module-facing `icedosLib` over the resolved
closure — so this repo contributes even when pulled in as a dependency (every DE
repo declares desktop as a **required** dependency for exactly this reason); it
only receives core's base `icedosLib`, so no other repo's contributions are
visible inside it — cross-repo composition happens at the module layer.

## Module shape here
Standard IceDOS module under `options.icedos.desktop.<name>`.

## Test a change to this repo
In the config root's `config.toml`, point this repo's `overrideUrl` at your local
checkout (`path:/abs/path/to/desktop`), then `icedos rebuild --build` (no activation).

## Notable modules / gotchas
- `gdm` (display manager/autologin), `stylix` (system theming + accent color),
  `displays`, `clear-xdg-portals`, `adwaita-qt`, `cosmic-greeter`, `entries`
  (`icedos.desktop.entries` → desktop launchers), `session`, `startup`, `plm`.
- **stylix** carries several IceDOS-specific quirks (Qt target disabled under Plasma6,
  KDE selection-fg patch, GDM/nixos-icons target disabled to avoid rebuilds). Check the
  module before changing theming behavior.
- **displays**: the xprimary state file lives at
  `${XDG_RUNTIME_DIR:-$HOME/.cache}/icedos/primary-display` (per-user; never `/tmp`,
  which is shared/world-writable). Both the `displays xprimary` toolset command and the
  `xprimary` systemd user service must resolve the same path — keep the shared
  `tempConfigPath`/`primaryDisplayPath` let-bindings in sync if either changes. The
  service validates the name read back from the file before passing it to xrandr.
- **entries** (`icedos.desktop.entries`): every entry must carry a non-empty string
  `id` (it becomes the desktop-entry key); enforced by a point-of-use throw when the
  desktop-entries map is evaluated.
- **clear-xdg-portals** uses `rm -rf --` and the `/run/wrappers/bin/sudo` setuid
  wrapper (a store-path sudo is not setuid), with `[ -e ]` guards on the system-wide
  deletions.

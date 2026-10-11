# codex-flake

Run the **official ChatGPT / Codex desktop app** (the Linux build OpenAI ships)
on NixOS, declaratively.

OpenAI only distributes Linux as an Ubuntu `.deb` — there is no Nix package and
no source. This flake unpacks that `.deb` and wraps the bundled Electron binary
in a `buildFHSEnv` sandbox so it finds the `/usr/lib` layout it expects at
runtime. Everything is pinned (deb hash + `flake.lock`), so the build is
reproducible.

> **Unofficial.** This repo only contains packaging glue (MIT). The app itself is
> proprietary, © OpenAI, and is downloaded directly from OpenAI's servers at
> build time. You are responsible for complying with OpenAI's terms.

Supported: `x86_64-linux` only (the vendor `.deb` is `amd64`).

---

## Quick start

```sh
# Run without installing
nix run github:Realdhiru/codex-flake
```

## Requirements

- NixOS (or any Nix + unprivileged user namespaces) on `x86_64-linux`.
- `nix-command` + `flakes` enabled (`experimental-features = nix-command flakes`).
- Internet access at build time (downloads the ~497 MB `.deb` once).
- A ChatGPT account at runtime. You do **not** need the `codex` CLI installed —
  the app bundles its own.

## Install (NixOS — recommended)

Add this flake as an input and import the module. It installs the package, wires
the overlay, and permits the one unfree package (your other `allowUnfree` choices
are preserved).

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Local path while developing:
    # chatgpt.url = "path:/home/you/Projects/codex-flake";
    # Once published:
    chatgpt.url = "github:Realdhiru/codex-flake";
    chatgpt.inputs.nixpkgs.follows = "nixpkgs";   # reuse your nixpkgs
  };

  outputs = { self, nixpkgs, chatgpt, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        chatgpt.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Then:

```sh
sudo nixos-rebuild switch --flake .#myhost
```

The app appears in your launcher as **ChatGPT**. First build downloads ~497 MB.

### Home Manager

```nix
imports = [ inputs.chatgpt.homeModules.default ];
# or imperatively:
# home.packages = [ inputs.chatgpt.packages.${pkgs.system}.default ];
```

### Imperative install

```sh
nix profile install github:Realdhiru/codex-flake#chatgpt
```

### Overlay (if you manage pkgs yourself)

```nix
nixpkgs.overlays = [ inputs.chatgpt.overlays.default ];
# then: environment.systemPackages = [ pkgs.chatgpt ];
```

Your nixpkgs must allow the unfree package:

```nix
nixpkgs.config.allowUnfreePredicate =
  pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "chatgpt" ];
```

---

## How it works

1. `fetchurl` downloads the pinned `.deb` (hash-checked; a bad/expired URL fails,
   it never silently fetches something else).
2. `dpkg-deb -x` unpacks it to a store path.
2. `buildFHSEnv` creates a bubblewrap sandbox exposing an FHS `/usr` tree plus the
   shared libraries the bundled Chromium dlopens (`gtk3`, `nss`,
   `libgbm`, `libGL`, `alsa-lib`, X libs, ...), and exposes `bin/chatgpt`.
3. `symlinkJoin` merges in the `.desktop` entry and icon.

Native Wayland is forced via `--ozone-platform=wayland` (raw Chromium switch);
OpenAI's custom Chromium runtime does not honor `ELECTRON_OZONE_PLATFORM_HINT`,
so that env var is a no-op.

## Why not just `pkgs.chatgpt`?

nixpkgs's `chatgpt` attribute is macOS-only (`aarch64-darwin`). It cannot build
this Linux app. This flake shadows the name for Linux.

## Reproducibility

- The `.deb` is pinned by `sha256`; `nixpkgs` is pinned by `flake.lock`.
- Anyone building from a given commit of this repo gets a byte-identical result
  (modulo their CPU/arch, which is fixed here to `x86_64-linux`).
- **Caveat:** the download URL is a `/latest/` path. When OpenAI publishes a new
  build the pinned hash stops matching and the build **fails** (it never
  silently upgrades). You then bump `version` + `sha256` (below). Old commits
  keep working only until OpenAI deletes that file, which they do not version.

## Updating the version

```sh
# 1. Try to build; it fails with the new hash in the error:
nix build .#chatgpt
#    error: hash mismatch ... got: sha256-XXXX...
# 2. Paste the new sha256 (and bump `version`) in pkgs/chatgpt.nix
# 3. Rebuild:
nix build .#chatgpt
```

Optional: `nix flake update` to refresh nixpkgs.

## Runtime requirements

- **User namespaces**: the FHS sandbox uses `bwrap`. On NixOS this is enabled by
  default (`security.unprivilegedUsernsClone` is not needed unless you hardened
  it). If you disabled unprivileged user namespaces, the wrapper will fail.
- **GPU/display**: works under Wayland (Hyprland, GNOME, KDE) and X11.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `hash mismatch` on build | Version bumped upstream — see "Updating the version". |
| `Package ‘chatgpt’ ... has an unfree license` | Use the NixOS/Home module (handles it), or set `nixpkgs.config.allowUnfree = true`. |
| Launcher does nothing / no `chatgpt` on PATH | Ensure `bin/chatgpt` exists: `ls result/bin`. The wrapper name comes from `executableName`. |
| `libgbm.so.1: cannot open shared object file` | `libgbm` was split out of `mesa`; ensure it is in `targetPkgs` (it is here). |
| Blank window / GPU crash | Try `--disable-gpu` or `--disable-features=Vulkan`. Also confirm native Wayland: `hyprctl clients | grep -A2 -i chatgpt` should show `xwayland: 0`. |
| `bwrap: ... permission denied` | Unprivileged user namespaces are disabled on your kernel. |
| Runs in XWayland (X11) | Check launch args: should include `--ozone-platform=wayland`. `NIXOS_OZONE_WL` doesn't affect this custom Chromium build. |

## License

The packaging code in this repository is MIT (see `LICENSE`). The ChatGPT
application itself is proprietary software owned by OpenAI and is **not**
distributed here — it is downloaded from OpenAI's servers at build time.

## CI & Auto-updates

- **Build and Cache**: GitHub Actions build `.#chatgpt` on push/PR; pushes to Cachix `codex-flake` on `main`.
- **Auto-bump**: Runs every 6 hours (and on manual dispatch). When OpenAI publishes a new `.deb`, the hash changes, CI opens a PR bumping it and verifies the build.
- **Local bump**: `./scripts/bump-version.sh` (build + verify locally).

For Cachix on your machine: `cachix use codex-flake` and add substituter if desired.

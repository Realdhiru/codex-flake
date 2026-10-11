{
  description = "ChatGPT / Codex desktop (official Linux build) packaged for NixOS";

  # Pinned via flake.lock -> reproducible. Bump with `nix flake update`.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" ];
      forAllSystems = f: lib.genAttrs systems (system: f system);

      # nixpkgs instance that permits this one unfree package without forcing the
      # consumer to globally set allowUnfree = true.
      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [ "chatgpt" ];
      };
    in
    {
      packages = forAllSystems (system:
        let pkgs = pkgsFor system; in {
          chatgpt = pkgs.callPackage ./pkgs/chatgpt.nix { };
          default = self.packages.${system}.chatgpt;
        });

      # Advanced: add `inputs.chatgpt.overlays.default` to nixpkgs.overlays.
      # NOTE: your nixpkgs must allow the (unfree) package yourself.
      overlays.default = final: prev: {
        chatgpt = final.callPackage ./pkgs/chatgpt.nix { };
      };

      # `nix run github:Realdhiru/codex-flake`
      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/chatgpt";
        };
      });

      # NixOS: imports = [ inputs.chatgpt.nixosModules.default ];
      nixosModules.default = { pkgs, lib, ... }: {
        nixpkgs.overlays = [ self.overlays.default ];
        nixpkgs.config.allowUnfreePredicate = lib.mkDefault (pkg:
          builtins.elem (lib.getName pkg) [ "chatgpt" ]);
        environment.systemPackages = [ pkgs.chatgpt ];
      };

      # Home Manager: imports = [ inputs.chatgpt.homeModules.default ];
      homeModules.default = { pkgs, ... }: {
        nixpkgs.overlays = [ self.overlays.default ];
        home.packages = [ pkgs.chatgpt ];
      };
    };
}

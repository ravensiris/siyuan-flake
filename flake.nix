{
  description = "Nix flake for SiYuan — a privacy-first personal knowledge management system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # NixOS module — usable on any system
      nixosModule = import ./module.nix self;
    in
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          siyuan = pkgs.siyuan;
          default = pkgs.siyuan;
        };

        # Expose just the kernel binary for server/headless use
        apps.default = {
          type = "app";
          program = "${pkgs.siyuan}/share/siyuan/resources/kernel/SiYuan-Kernel";
        };

        apps.siyuan-desktop = {
          type = "app";
          program = "${pkgs.siyuan}/bin/siyuan";
        };

        apps.siyuan-server = {
          type = "app";
          program = "${pkgs.siyuan}/share/siyuan/resources/kernel/SiYuan-Kernel";
        };
      }
    ) // {
      nixosModules.default = nixosModule;
      nixosModules.siyuan = nixosModule;

      overlays.default = final: prev: {
        siyuan = prev.siyuan;
      };
    };
}

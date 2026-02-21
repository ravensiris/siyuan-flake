# siyuan-flake

Nix flake for [SiYuan](https://github.com/siyuan-note/siyuan) — a privacy-first, self-hosted personal knowledge management system.

## Outputs

| Output | Description |
|--------|-------------|
| `packages.<system>.siyuan` | SiYuan desktop application (Electron) |
| `apps.<system>.siyuan-desktop` | Run SiYuan desktop GUI |
| `apps.<system>.siyuan-server` | Run SiYuan kernel (headless server) |
| `nixosModules.siyuan` | NixOS module for running SiYuan as a systemd service |
| `overlays.default` | Nixpkgs overlay |

## Quick start

### Run the desktop app

```sh
nix run github:clairesrc/siyuan-flake#siyuan-desktop
```

### Run the server (headless)

```sh
nix run github:clairesrc/siyuan-flake#siyuan-server -- \
  --port 6806 \
  --workspace ~/SiYuan
```

## NixOS module

Add to your `flake.nix`:

```nix
{
  inputs.siyuan-flake.url = "github:clairesrc/siyuan-flake";

  outputs = { nixpkgs, siyuan-flake, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        siyuan-flake.nixosModules.siyuan
        {
          services.siyuan = {
            enable = true;
            port = 6806;
            host = "127.0.0.1";
            workspaceDir = "/var/lib/siyuan/workspace";
            accessAuthCode = "your-secret-code";
            lang = "en_US";
            openFirewall = false;
          };
        }
      ];
    };
  };
}
```

### Module options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the SiYuan server service |
| `package` | package | `pkgs.siyuan` | SiYuan package to use |
| `port` | int | `6806` | HTTP/WebSocket server port |
| `host` | string | `"127.0.0.1"` | Bind address (`"0.0.0.0"` for all interfaces) |
| `workspaceDir` | path | `"/var/lib/siyuan/workspace"` | Workspace directory |
| `accessAuthCode` | string | `""` | Access auth code (plaintext in Nix store) |
| `accessAuthCodeFile` | path or null | `null` | File containing the auth code (preferred) |
| `ssl` | bool | `false` | Enable HTTPS/WSS |
| `readOnly` | bool | `false` | Read-only mode |
| `lang` | enum | `""` | UI language |
| `user` | string | `"siyuan"` | System user |
| `group` | string | `"siyuan"` | System group |
| `openFirewall` | bool | `false` | Open firewall port |

### Using `accessAuthCodeFile` (recommended for secrets)

```nix
services.siyuan = {
  enable = true;
  accessAuthCodeFile = "/run/secrets/siyuan-auth";
};
```

This reads the auth code from a file at runtime, keeping it out of the Nix store.

## License

AGPL-3.0-or-later (same as SiYuan)

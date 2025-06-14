# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is lassulus's personal NixOS/nix-darwin configuration repository, built on clan-core for managing multiple machines. It includes:
- Multiple machine configurations in `machines/`
- Configuration modules in `2configs/` and `3modules/`
- Custom packages in `5pkgs/`
- Various network overlays (retiolum, spora, nether, zerotier, mycelium)

## Key Architecture Components

### Machine Management
- **Clan-core**: Primary framework for managing multiple machines
- **Inventory**: Machines are tagged in `flake.nix` (laptop/server tags)
- **Secrets**: Uses password-store for secrets management via clan.core.facts
- **Deployment**: Uses krops (via stockholm) for deployment

### Network Overlays
The repository manages multiple overlay networks:
- **Retiolum**: VPN network (access via `.r` suffix)
- **Spora**: Mycelium-based P2P network (access via `.s` suffix)  
- **Nether**: ZeroTier-based network overlay (access via `.n` suffix)
- **Tor**: Anonymous network access

### Module System
- `2configs/`: Main configuration modules (imported by all machines)
- `3modules/`: Custom NixOS module definitions
- Stockholm modules are also imported for krebs infrastructure

## Common Development Commands

```bash
# Enter development shell
nix develop

# Run interactive menu (default package)
nix run

# Deploy to a specific machine
nix run .#deploy -- <MACHINE_NAME>

# Format code
nix fmt

# Build NixOS configuration
nix build .#nixosConfigurations.<machine-name>.config.system.build.toplevel

# Build Darwin configuration
nix build .#darwinConfigurations.barnacle.system

# Deploy/rebuild Darwin configuration (for barnacle)
sudo darwin-rebuild switch --flake .#barnacle

# Access machines via SSH
ssh <machine-name>.r  # via retiolum
ssh <machine-name>.s  # via spora
ssh <machine-name>.n  # via nether
torify ssh $(pass show machines/<machine-name>/tor-hostname)  # via tor
```

## Important: Git Staging for Flake Evaluation

**CRITICAL**: New nix files must be staged (git add) before they are available in flake evaluation. When creating new packages, modules, or any nix files, always run `git add <files>` before testing with `nix build`, `nix run`, etc.

## Machine Facts and Secrets

Each machine stores its public facts in `machines/<name>/facts/` including:
- SSH public keys
- Network identities (retiolum, mycelium, zerotier)
- Syncthing IDs
- DKIM keys (for mail servers)

Secrets are managed via password-store and uploaded to `/etc/secrets` on deployment.

## Adding New Machines

1. Create directory `machines/<name>/`
2. Add `config.nix`, `physical.nix`, and optionally `disk.nix`
3. Generate facts using clan-cli
4. Add to inventory in `flake.nix`
5. Deploy using `nix run .#deploy -- <name>`

## Testing

- VM tests: `./5pkgs/init/test.sh`
- Container tests are configured in `2configs/container-tests.nix`

## Commit Message Guidelines

- Use simple, descriptive commit messages without attribution footers
- For flake.lock updates, use: "flake.lock: update"
- Follow existing patterns seen in git log

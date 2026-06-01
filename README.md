# envvault
I made this cause I wanted a simple way to get my per-repo .env files from my local; which sometimes
get lost by switching branches. 
I did not want any shell hooks, no automated loading.. so that rules out `direnv`. I also did not
want any repo-specific secret storage like `git-crypt`.
`pass` or `gopass` were possible, but I wanted something more self-contained without any separate
synced password-store setup. 


`envvault` is a simple CLI tool to store and retrieve per-repo environment variables in encrypted vault files. 
It's written in Zig and uses `age` for encryption.

```sh
envvault put dev
envvault get dev
envvault get dev --force
envvault list
envvault where dev
```

Vault files live under `~/.env-vault/<repo>/` and are encrypted with the external `age` binary using your default SSH key.

```sh
ENVVAULT_ROOT=~/.env-vault
ENVVAULT_IDENTITY=~/.ssh/id_ed25519
ENVVAULT_RECIPIENT=~/.ssh/id_ed25519.pub
```

`envvault` wont autoload variables, edits shell/Git config, or overwrites `.env` unless `--force` is passed.

```sh
zig build
zig build test
zig build test -Dtest-filter=parse
```

Install locally:

```sh
zig build -p "$HOME/.local" -Doptimize=ReleaseFast
```

Install system-wide:

```sh
sudo zig build -p /usr -Doptimize=ReleaseFast
```

`age` must also be installed and available on `PATH`.

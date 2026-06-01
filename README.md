# envault
I made this because I wanted a simple way to get my per-repo `.env` files back from a local encrypted vault. They sometimes get lost while switching branches or moving between project states.

I did not want shell hooks or automated loading, so that rules out `direnv`. I also did not want repo-specific secret storage like `git-crypt`. `pass` or `gopass` would work, but I wanted something self-contained without a separate synced password-store setup.

`envault` is a simple CLI tool to store and retrieve per-repo environment variables in encrypted vault files.
It's written in Zig and uses `age` for encryption.

```sh
envault put dev
envault get dev
envault get dev --force
envault list
envault where dev
```

Vault files live under `~/.envault/<repo>/` and are encrypted with the external `age` binary using your default SSH key.

```sh
ENAULT_ROOT=~/.envault
ENAULT_IDENTITY=~/.ssh/id_ed25519
ENAULT_RECIPIENT=~/.ssh/id_ed25519.pub
```

`envault` will not autoload variables, edit shell/Git config, or overwrite `.env` unless `--force` is passed.

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

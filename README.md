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
envault backup init --remote git@github.com:you/envault-backup.git
envault backup commit
envault backup push
envault yubikey doctor
envault yubikey setup --slot 9a
```

Vault files live under `~/.envault/<repo>/` and are encrypted with the external `age` binary using your default SSH key.
If you need different branches, what I do is:
```
envault put dev-main
envault put dev-feature-branch
..etc
```

```sh
ENVAULT_ROOT=~/.envault
ENVAULT_IDENTITY=~/.ssh/id_ed25519
ENVAULT_RECIPIENT=~/.ssh/id_ed25519.pub
ENVAULT_YUBIKEY=1
```

`envault` will not autoload variables, edit shell/Git config, or overwrite `.env` unless `--force` is passed.

If you want to back up every encrypted env snapshot, `envault backup init` turns `ENVAULT_ROOT` into a Git repository. `envault backup commit` stages only encrypted `*.env.age` files, so the backup repo should contain ciphertext, not plaintext `.env` files or SSH identities.

## Install

`age` must be installed and available on `PATH`.

Download a release binary from:

```text
https://github.com/nullwiz/envault/releases/latest
```

Available archives:

```text
envault-x86_64-linux-musl.tar.gz
envault-aarch64-linux-musl.tar.gz
envault-x86_64-macos.tar.gz
envault-aarch64-macos.tar.gz
envault-x86_64-windows.tar.gz
envault-aarch64-windows.tar.gz
```

Example:

```sh
curl -L -o envault.tar.gz https://github.com/nullwiz/envault/releases/latest/download/envault-x86_64-linux-musl.tar.gz
tar -xzf envault.tar.gz
./envault help
```

Or build from source:

```sh
zig build
zig build test
zig build test -Dtest-filter=parse
```

Install locally:

```sh
zig build -p "$HOME/.local" -Doptimize=ReleaseFast
envault help
```

Install system-wide:

```sh
sudo zig build -p /usr -Doptimize=ReleaseFast
```

If Zig reports a cache permission error in a restricted environment, put the
global cache somewhere writable:

```sh
zig build --global-cache-dir /tmp/zig-cache -p "$HOME/.local" -Doptimize=ReleaseFast
```

## YubiKey

YubiKey support uses `age-plugin-yubikey`, so `age` still handles the encryption
format and envault just manages the identity and recipient files.

Install both tools:

```sh
# macOS or Linux with Homebrew
brew install age age-plugin-yubikey

# Debian/Ubuntu
sudo apt-get install age pcscd
# Then install age-plugin-yubikey from its release package:
# https://github.com/str4d/age-plugin-yubikey/releases
```

On Linux, make sure `pcscd` is installed and running.

Check the local setup:

```sh
envault yubikey doctor
```

For a YubiKey that already has an age identity in a slot, write envault's
default YubiKey identity and recipient files:

```sh
envault yubikey setup --slot 9a
ENVAULT_YUBIKEY=1 envault put dev
ENVAULT_YUBIKEY=1 envault get dev
```

To provision a new age identity on the YubiKey, use `generate` instead:

```sh
envault yubikey generate --slot 9a --name envault --pin-policy once --touch-policy cached
```

The default YubiKey files are:

```text
~/.envault/yubikey-identity.txt
~/.envault/yubikey-recipient.txt
```

You can override those paths with `--identity` and `--recipient`, or with
`ENVAULT_IDENTITY` and `ENVAULT_RECIPIENT`.

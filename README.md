# Eternal Terminal for iSH

This repository is a focused fork of [MisterTea/EternalTerminal](https://github.com/MisterTea/EternalTerminal) that exists solely to track the customizations we need for running the Eternal Terminal (ET) client inside [iSH](https://ish.app/) on iOS. It mirrors upstream `master`, but layers on top the build scripts, packaging artifacts, and tiny code changes that allow us to ship a 32‑bit musl client plus the assets we use to connect back to our Google Cloud environment.

Upstream still documents and ships all of the other platform packages. If you need anything besides the iSH story, read their README instead.

## What’s Different from Upstream

- **iSH build + artifacts** – `scripts/build-ish-client.sh`, `docker/ish-client/Dockerfile`, and the doc in `docs/build-ish-client.md` create and describe a reproducible Docker pipeline that emits:
  - `dist/ish/et-client-ish.tar.gz` – the ready-to-extract client bundle for iSH.
  - `dist/ish/et-ish.apk` – an Alpine `apk` you can host for any iSH installs that prefer `apk add`.
  - `dist/ish/usr/local/bin/et` – the unpacked binary for debugging or side-loading.
- **Stack trace toggle** – `cmake` now exposes `ENABLE_STACKTRACE` (ON by default). When the iSH build disables it we define `ET_DISABLE_STACKTRACE` so the binary has zero dependency on `UniversalStacktrace`/`libunwind`, which iSH cannot provide.
- **Documentation updates** – the README (this file) and `docs/build-ish-client.md` now talk about the iSH workflow instead of generic distro packages.
- **Ignored artifacts** – `dist/` is intentionally committed here (it contains the blessed artifacts we hand to testers), but `.gitignore` was updated so future dist builds stay under version control.

Everything else is kept identical to upstream so rebasing stays painless.

## Repository Landmarks

| Path | Purpose |
| ---- | ------- |
| `dist/ish/` | Shipping artifacts for iSH (tarball, APK, unpacked binary tree). |
| `docker/ish-client/` | Dockerfile that cross-builds the 32-bit musl client via BuildKit. |
| `scripts/build-ish-client.sh` | One-button wrapper that syncs submodules and runs the Docker build. |
| `docs/build-ish-client.md` | Step-by-step doc for the build pipeline and installation methods. |

## Installing the Prebuilt iSH Client

Pick whichever format is more convenient to side-load into iSH.

### Tarball Install (preferred while testing)

1. Copy `dist/ish/et-client-ish.tar.gz` into the iSH filesystem (AirDrop into Files, then `mv` inside iSH).
2. Extract it at the filesystem root so the files land on the expected paths:

   ```sh
   tar -xzf /path/to/et-client-ish.tar.gz -C /
   ```

That lays down `/usr/local/bin/et` plus the musl libs it needs under `/usr/local/lib/et`.

### APK Install

1. Host `dist/ish/et-ish.apk` somewhere reachable (GitHub release, GCS, etc.).
2. Inside iSH, point `apk` at it:

   ```sh
   apk add --allow-untrusted https://<host>/et-ish.apk
   ```

You can then manage ET with normal Alpine package commands.

## iSH Environment Checklist

These are the bits we validated during bring-up; skipping any of them is what usually causes “Could not reach server” or “invalid format” errors.

1. **Install OpenSSH tools** inside iSH:

   ```sh
   apk update && apk add openssh
   ```

2. **Host mapping** – iSH does not read macOS’ `/etc/hosts`, so add the entry manually if you rely on hostnames:

   ```sh
   echo '<server-ip> et-host' >> /etc/hosts
   ```

3. **SSH credentials** – copy the private key (`~/.ssh/google_compute_engine` in our case), the public half, and the known-hosts file into iSH. Make sure permissions stay strict:

   ```sh
   chmod 600 ~/.ssh/google_compute_engine ~/.ssh/google_compute_known_hosts
   ```

4. **SSH config** – ET shells out to `ssh`, so add the host stanza so both `ssh et-host` and `et et-host` succeed:

```ssh-config
Host et-host
  HostName <server-ip-or-dns>
  User <user>
  IdentityFile ~/.ssh/<private_key>
  StrictHostKeyChecking no
  UserKnownHostsFile ~/.ssh/<known_hosts_file>
```

5. **Smoke test SSH** – run `ssh et-host` before touching ET. If SSH reaches the VM, `et et-host` will work.

## Using ET Against Your Server

Once the client binary is in place and SSH works, the workflow is the same as on macOS:

```sh
et et-host              # default port 2022
et et-host:2222 -u foo  # override port/user if needed
```

`et` will auto-reconnect if your phone drops LTE/Wi‑Fi, which is the whole reason this fork exists.

## Building Fresh Artifacts

Everything lives in Docker so the macOS toolchain stays untouched.

```bash
git pull --rebase
git submodule update --init --recursive
scripts/build-ish-client.sh
```

The script:

- Ensures submodules are synced (set `SKIP_SUBMODULE_UPDATE=1` to opt out).
- Uses `docker buildx` to compile the 32-bit musl client.
- Exports the artifacts into `dist/ish/`.
- Forces `-DET_DISABLE_STACKTRACE` so the binary has no unavailable dependencies inside iSH.

See `docs/build-ish-client.md` for the long-form explanation plus troubleshooting.

## Upstream Resources

- Main project docs, changelog, and installation guides live at <https://github.com/MisterTea/EternalTerminal>.
- Packaging for macOS (Homebrew/MacPorts), Linux distros, Windows/WSL, etc. continues to be maintained upstream. Use their README for anything that is not the iSH workflow described here.

If you add more iSH-specific tweaks, please document them in this README so we keep a single source of truth for our fork.

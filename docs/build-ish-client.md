# Eternal Terminal Client Build for iSH

This workflow produces a 32-bit musl build of the Eternal Terminal client that runs inside iSH on iOS. Everything happens inside Docker so the host macOS toolchain stays untouched.

## Prerequisites

- Docker Desktop with BuildKit/Buildx enabled (`docker buildx version` should work)
- A clean checkout with submodules (`git submodule update --init --recursive`)

## Build Steps

From the repository root:

```bash
scripts/build-ish-client.sh
```

The script:

- Ensures submodules are up to date (unless `SKIP_SUBMODULE_UPDATE=1`)
- Uses `docker buildx build` with the `docker/ish-client/Dockerfile` to compile the client for `linux/386` on Alpine (musl)
- Exports the artifacts to `dist/ish`
- Disables optional stack-trace capture to avoid any `libunwind` dependency inside iSH

Outputs:

- `dist/ish/et-client-ish.tar.gz` – ready to AirDrop/SCP to the device
- `dist/ish/et-ish.apk` – installable via `apk add --allow-untrusted`
- `dist/ish/usr/local/bin/et` – unpacked binary for inspection

### Optional: Skipping Submodule Updates

If file permissions prevent `git submodule update`, set `SKIP_SUBMODULE_UPDATE=1` when running the build script. Make sure submodules are already initialized beforehand.

## Installing Inside iSH (Tarball Method)

1. Transfer `et-client-ish.tar.gz` to the iOS device (AirDrop, Files app, etc.).
2. Extract the archive to `/` so the binary (and its bundled libraries) land on the PATH:

   ```sh
   tar -xzf /path/to/et-client-ish.tar.gz -C /
   ```

The client is now available at `/usr/local/bin/et`, with its private copies of required shared libraries in `/usr/local/lib/et`. No additional Alpine packages are needed.

## Installing Inside iSH via `apk add`

The packaged build also emits `dist/ish/et-ish.apk`, which bundles the same files in Alpine package format. Host the APK somewhere reachable (e.g., GitHub Releases or object storage) and install it directly:

```sh
apk add --allow-untrusted https://example.com/path/to/et-ish.apk
```

This installs `/usr/local/bin/et` and `/usr/local/lib/et` and lets users upgrade/remove the client with standard `apk` tooling.

Re-run the script any time; it is idempotent and reuses Docker layer caches.

## Usage

Verify the binary:

```sh
et --version
```

Connect to your Eternal Terminal server (running on a remote host):

```sh
et user@your-server.example.com
```

Remember: the iSH build only provides the client; you still need an ET server reachable over the network.

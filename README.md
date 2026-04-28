# Bitcoin Core - UBI 10 Minimal, rootless, GPG-verified

A production-ready container image for Bitcoin Core built on UBI 10 minimal from Red Hat. The build downloads bitcoin-core from [official sources](https://bitcoincore.org/bin/) and verifies it cryptographically with SHA256 and GnuPG before building the image. The container runs rootless for enhanced security.

### Key Features

- **Secure**: GPG-verified downloads, rootless container execution, minimal attack surface
- **Lightweight**: Based on UBI 10 minimal (~90 MB base image)
- **Verified**: SHA256 and GPG signature verification of Bitcoin Core binaries
- **Multi-arch**: Supports x86_64, aarch64, and arm64 architectures
- **Pruned by default**: ~10 GiB storage requirement (full node: ~750 GB)

## Prerequisites

- **Docker**: 20.10+ and Docker Compose 2.0+
- **Storage**: 
  - Pruned mode (default): ~15 GiB (10 GiB blockchain + overhead)
  - Full node mode: ~750 GiB
- **Memory**: Minimum 2 GB RAM (4 GB recommended)
- **Network**: Open ports 8333 (P2P) and 8332 (RPC, localhost only)

## Quick Start

1. **Generate a secure RPC password**:
```sh
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

2. **Update `bitcoin.conf`**:
   Replace `CHANGE_ME_TO_SOMETHING_SECURE` with the generated password.

3. **Start the container**:
```sh
docker compose up -d
```

4. **Verify it's running**:
```sh
docker compose logs -f bitcoind
```

## Understanding the Configuration

### Storage Modes

- **Pruned Mode (default)**: Keeps only the last ~10 GB of blockchain. Suitable for most use cases. Use `prune=10000` in `bitcoin.conf`.
- **Full Node Mode**: Keeps the entire blockchain (~750 GB). Set `prune=0` in `bitcoin.conf`.

Note: Pruned mode is incompatible with features like `txindex`, wallet operations, and `rescan`.

### Ports

- **8333** (P2P Network): Bitcoin peer-to-peer connections. Required for participating in the network.
- **8332** (RPC): Remote Procedure Call interface. Restricted to localhost (127.0.0.1) for security.

### Important `bitcoin.conf` Settings

```ini
# Server and logging
server=1                     # Enable RPC server
printtoconsole=1            # Log to stdout (useful in Docker)
listen=1                    # Accept P2P connections

# RPC security
rpcallowip=172.16.0.0/12   # Allow Docker network IPs
rpcbind=0.0.0.0             # Bind to all interfaces (filtered by rpcallowip)
rpcuser=bitcoinrpc          # RPC username
rpcpassword=CHANGE_ME_TO_SOMETHING_SECURE # Generated token

# Storage and performance
prune=10000                 # Pruned mode: 10 GB
dbcache=512                 # Database cache in MB
maxconnections=40           # Limit peer connections
```

## Usage Examples

### Using docker-compose

```sh
# Start the container
docker compose up -d

# Stop the container
docker compose down

# View logs
docker compose logs -f bitcoind

# Access Bitcoin CLI
docker compose exec bitcoind bitcoin-cli getblockchaininfo
```

### Using bitcoin-cli Commands

```sh
# Get blockchain info
docker compose exec bitcoind bitcoin-cli getblockchaininfo

# Get network info
docker compose exec bitcoind bitcoin-cli getnetworkinfo

# Get wallet info (if wallet is enabled)
docker compose exec bitcoind bitcoin-cli getwalletinfo

# Get peer connections
docker compose exec bitcoind bitcoin-cli getpeerinfo

# Stop the daemon gracefully
docker compose exec bitcoind bitcoin-cli stop
```

## Building

This project uses `make` and `docker` (or `podman`) for building secure, multi-architecture container images.

### Prerequisites for Building

- `make` installed
- Docker with `buildx` support (or `podman`)
- Internet connection (to download Bitcoin Core and GPG keys)

### Configuration

You **must** create your own secure RPC password in `bitcoin.conf` before building:

```sh
# Generate a secure password
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Edit bitcoin.conf and replace CHANGE_ME_TO_SOMETHING_SECURE
vi bitcoin.conf
```

### Build Variables

- **`BITCOIN_VERSION`** - Bitcoin Core version to build (default: 31.0)
  ```sh
  make build BITCOIN_VERSION=31.0
  ```

- **`ARCH`** - Target architecture (default: detected from `uname -m`)
  - `x86_64` → Linux AMD64
  - `aarch64` → ARM 64-bit (alternative form)
  - `arm64` → ARM 64-bit (macOS form, converted to aarch64)
  
  ```sh
  make build ARCH=aarch64
  ```

- **`IMAGE_NAME`** - Container image name (default: `bitcoin-core`)
  ```sh
  make build IMAGE_NAME=my-bitcoin
  ```

- **`REGISTRY`** - Container registry for pushing images (optional)
  ```sh
  make build REGISTRY=ghcr.io/jonasbjork/bitcoin-core
  ```

- **`TAG`** - Image tag (default: version number)
  ```sh
  make build TAG=31.0-fullnode
  ```

- **`CONTAINER_RT`** - Container runtime (default: `docker`)
  ```sh
  make build CONTAINER_RT=podman
  ```

### Available Make Commands

Run `make help` to see all available targets:

```sh
make build              # Build the image with default settings
make build BITCOIN_VERSION=31.0 ARCH=aarch64  # Custom build
make lint               # Lint the Dockerfile using hadolint
make push               # Push image to registry (requires REGISTRY variable)
make clean              # Remove local images
```

### Build Examples

```sh
# Build default (v31.0) for your current architecture
make build

# Build Bitcoin Core v30.0 for ARM64 (macOS)
make build BITCOIN_VERSION=30.0 ARCH=arm64

# Build and lint
make lint
make build

# Build with registry for pushing
make build REGISTRY=ghcr.io/jonasbjork/bitcoin-core
make push
```

### Verification

After building, verify the image:

```sh
# List images
docker images | grep bitcoin-core

# Run a test container
docker run --rm ghcr.io/jonasbjork/bitcoin-core:latest bitcoind -version
```


## Troubleshooting

### Container fails to start

**Error**: `Error response from daemon: OCI runtime error`

- Verify sufficient disk space: `df -h`
- Check Docker daemon is running: `docker ps`
- View detailed logs: `docker compose logs bitcoind`

### High Memory Usage

Bitcoin Core caches blockchain data in memory. Adjust in `bitcoin.conf`:

```ini
# Reduce memory usage (1-4 GB range typical)
dbcache=256    # Reduce from 512
```

Restart the container:
```sh
docker compose restart bitcoind
```

### Sync Slow or Stuck

- Check peers: `docker compose exec bitcoind bitcoin-cli getpeerinfo | head`
- Verify network: `docker compose exec bitcoind bitcoin-cli getnetworkinfo`
- May take 24-48 hours for initial sync depending on network/hardware

### RPC Connection Refused

- Verify container is running: `docker compose ps`
- Check RPC port binding: `docker compose logs bitcoind | grep rpc`
- Ensure password has no special characters that need escaping in `bitcoin.conf`

### Permission Issues

Bitcoin Core runs as user `bitcoin` (UID 1001). The container uses a read-only filesystem except for data volumes.

- Ensure volume permissions: `chmod 700 /path/to/bitcoin/data`
- Avoid running as root

## Architecture Support

| Architecture | ARCH Value | Platform | Status |
|-------------|-----------|----------|--------|
| Intel/AMD 64-bit | `x86_64` | linux/amd64 | ✅ Supported |
| ARM 64-bit | `aarch64` or `arm64` | linux/arm64 | ✅ Supported |

On macOS with Apple Silicon, use `arm64` (automatically converted to `aarch64`):
```sh
make build ARCH=arm64
```

## Security Considerations

- **Rootless**: Container runs as non-root user (bitcoin:1001)
- **Read-only filesystem**: Most filesystem is read-only; only `/tmp` and data volume are writable
- **RPC security**: RPC interface bound to `127.0.0.1` by default (localhost only)
- **Resource limits**: Memory capped at 4GB via `docker-compose.yml`
- **GPG verification**: All Bitcoin Core binaries verified before image build
- **No setuid**: No setuid binaries in image

## References

- [Bitcoin Core Official](https://bitcoincore.org/)
- [Bitcoin Core Documentation](https://bitcoincore.academy)
- [UBI 10 Minimal](https://catalog.redhat.com/en/software/containers/ubi10/ubi/66f2b46b122803e4937d11ae)

## Todo

- Integrate Tor support for enhanced privacy
- Add Prometheus metrics export
- Support for custom Bitcoin Core builds


# Nix `--rebuild` on Darwin leaves stale `<out>.tmp` after interruption

Minimal reproduction for a Darwin `nix build --rebuild` failure mode where interrupting the client during the hash-rewrite phase leaves a root-owned `/nix/store/...tmp` path behind, and the next rebuild fails because that temp path still exists.

## Reproduction

```bash
./repro.sh
```

This was reproduced with multi-user Determinate Nix on macOS. The script:

1. realizes a tiny two-output derivation,
2. starts `nix build .#multi --rebuild`,
3. waits until the log shows `rewriting hashes in ...`,
4. kills the client,
5. confirms that `/nix/store/...rebuild-multi-output.tmp` was stranded, and
6. runs `nix build .#multi --rebuild` again, which then fails with an existing-temp-path error.

## Expected

Interrupting the client during `nix build --rebuild` should not leave a stale temp path in `/nix/store`, or Nix should recover from it on the next rebuild attempt.

## Actual

The interrupted rebuild leaves a root-owned temp path in `/nix/store`, for example:

```text
/nix/store/...-darwin-rebuild-stale-tmp.tmp
```

The next rebuild fails with:

```text
checking outputs of '/nix/store/...-darwin-rebuild-stale-tmp.drv'...
error: path '/nix/store/...-darwin-rebuild-stale-tmp.tmp' already exists
```

In a larger real-world derivation, the same stale-temp-path family showed up as a nested copy error instead:

```text
error: filesystem error: in copy: File exists [...] ["/nix/store/...-pnpm-deps-....tmp/..."]
```

## Cleanup

On multi-user Nix, the stranded temp path is root-owned, so cleanup usually needs elevated privileges:

```bash
sudo rm -rf /nix/store/*darwin-rebuild-stale-tmp*.tmp
```

## Versions

- Nix: 2.33.3
- Determinate Nix: 3.17.1
- OS: macOS 26.3.1 (`aarch64-darwin`)

## Related Issue

TBD

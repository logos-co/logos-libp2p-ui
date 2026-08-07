# Logos libp2p UI

The Logos libp2p UI is an initial Qt/QML dashboard for managing the
`libp2p_module` inside Logos Core.

## Run

```bash
nix run
```

## Build

```bash
nix build
```

The app follows the same C++/Qt/QML/Nix structure as `logos-storage-ui`, with a
C++ backend exposed to QML through Qt Remote Objects.

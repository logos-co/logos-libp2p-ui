{ system ? builtins.currentSystem }:

let
  workspace = ../..;
  nimLibp2p = workspace + "/nim-libp2p";
  nimLibp2pFlake = builtins.getFlake (toString nimLibp2p);
  pkgs = import nimLibp2pFlake.inputs.nixpkgs { inherit system; };
  deps = import (nimLibp2p + "/nix/deps.nix") { inherit pkgs; };
  dependencyPaths = builtins.concatStringsSep " " (
    map (path: "--path:${path}") (builtins.attrValues deps)
  );
in
pkgs.stdenv.mkDerivation {
  pname = "logos-libp2p-ui-swarm";
  version = "dev";
  src = ./.;

  nativeBuildInputs = [ pkgs.nim-2_2 ];

  buildPhase = ''
    runHook preBuild
    # nim invokes gcc for the final link. BoringSSL, pulled in by the Noise
    # transport, contains C++ objects, so explicitly link its runtime.
    nim c --passL:-lstdc++ --noNimblePath --nimcache:$TMPDIR/nimcache ${dependencyPaths} --path:${nimLibp2p} -o:ui-swarm ui_swarm.nim
    runHook postBuild
  '';

  installPhase = ''
    install -Dm755 ui-swarm $out/bin/ui-swarm
  '';
}

{
  description = "libp2p UI plugin for the Logos application";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    nix-bundle-lgx.url = "github:logos-co/nix-bundle-lgx";
    libp2p_module.url = "path:/home/vlado/workspace/ift/logos-libp2p-module";
  };

  outputs = inputs@{ logos-module-builder, ... }:
    let
      lib = logos-module-builder.inputs.nixpkgs.lib;

      sourceFilter = path: type:
        let
          name = baseNameOf path;
        in
          lib.cleanSourceFilter path type
          && !(type == "directory" && builtins.elem name [
            ".cache"
            "build"
            "build-qml"
            "generated_code"
          ])
          && !(name == "CMakeCache.txt");

      cleanSrc = lib.cleanSourceWith {
        src = ./.;
        filter = sourceFilter;
      };

      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];

      module = logos-module-builder.lib.mkLogosQmlModule {
        src = cleanSrc;
        configFile = ./metadata.json;
        flakeInputs = inputs;
      };

      appWithSoftwareSceneGraph = system:
        let
          pkgs = import logos-module-builder.inputs.nixpkgs { inherit system; };
          defaultApp = module.apps.${system}.default;
          run = pkgs.writeShellApplication {
            name = "run-logos-standalone-ui";
            text = ''
              export QSG_RHI_BACKEND="''${QSG_RHI_BACKEND:-software}"
              export QT_QUICK_BACKEND="''${QT_QUICK_BACKEND:-software}"
              exec ${defaultApp.program} "$@"
            '';
          };
        in {
          type = "app";
          program = "${run}/bin/run-logos-standalone-ui";
        };
    in
      module // {
        apps = lib.genAttrs systems (system:
          (module.apps.${system} or {}) // {
            default = appWithSoftwareSceneGraph system;
          }
        );
      };
}

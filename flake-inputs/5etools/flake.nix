{
  description = "5etools 2014 static site package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};

      version = "1.217.0";
      rev = "da55a2820fb547651d9e2833262fb73ce9ce969e";
      imgRev = "600239dce888ed65e5409ef7c5c9dd7dbea67599";
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;

          imgSrc = pkgs.fetchFromGitHub {
            owner = "5etools-mirror-3";
            repo = "5etools-img";
            rev = imgRev;
            hash = "sha256-TPfTnCo0QO0xTV8rCk2KjYYwI+6st4wn1FXI6zQt8No=";
          };

          images = pkgs.symlinkJoin {
            name = "5etools-img-${builtins.substring 0 7 imgRev}";
            paths = [ imgSrc ];
            meta = {
              description = "Image assets for 5etools";
              homepage = "https://github.com/5etools-mirror-3/5etools-img";
              license = pkgs.lib.licenses.mit;
              platforms = pkgs.lib.platforms.all;
            };
          };
        in
        {
          inherit images;

          default = pkgs.buildNpmPackage {
            pname = "5etools-2014";
            version = "${version}-${builtins.substring 0 7 rev}";

            src = pkgs.fetchFromGitHub {
              owner = "5etools-mirror-3";
              repo = "5etools-2014-src";
              inherit rev;
              hash = "sha256-QFBUdPl0iVbmmQoS1D8oEbtJQ5zr9RejpFhGHdKH3Bo=";
            };

            npmDepsHash = "sha256-RzR9igAhEfF7bLDme3UaL1uqY07sdFBhS/YvTynWlz4=";
            nodejs = pkgs.nodejs_24;
            nativeBuildInputs = [ pkgs.rsync ];

            postPatch = ''
              substituteInPlace js/utils.js \
                --replace-fail 'globalThis.IS_DEPLOYED = undefined;' 'globalThis.IS_DEPLOYED = "${version}";' \
                --replace-fail 'globalThis.DEPLOYED_IMG_ROOT = undefined;' 'globalThis.DEPLOYED_IMG_ROOT = "/img/";'
            '';

            npmBuildScript = "build";

            installPhase = ''
              runHook preInstall

              mkdir -p "$out"
              rsync -a \
                --exclude node_modules \
                --exclude .cache \
                ./ "$out"/
              ln -s ${images} "$out/img"

              runHook postInstall
            '';

            meta = {
              description = "Static 5etools 2014 site";
              homepage = "https://github.com/5etools-mirror-3/5etools-2014-src";
              license = pkgs.lib.licenses.mit;
              platforms = pkgs.lib.platforms.all;
            };
          };
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [ pkgs.nodejs pkgs.python3 ];
          };
        }
      );
    };
}

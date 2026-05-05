{
  description = "registrar";
  nixConfig = {
    allow-import-from-derivation = true;
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Git hooks
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    pre-commit-hooks,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        inherit (self.checks.${system}) pre-commit-check;
        # pkgs = import nixpkgs {localSystem = {inherit system;};};
        pkgs = nixpkgs.legacyPackages.${system};
        hlib = pkgs.haskell.lib;
        hpkgs = pkgs.haskell.packages."ghc912".override {
          overrides = self: super: {
            postgresql-simple = hlib.dontCheck (hlib.doJailbreak super.postgresql-simple);
          };
        };
      in {
        # Tests and suites for this repo
        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              statix.enable = true;
              treefmt.enable = true;
            };
          };
        };

        packages.default = pkgs.haskell.lib.overrideCabal (hpkgs.callCabal2nix "persistent-records" ./. {}) (old: {
          doCheck = true;
          doHaddock = false;
          enableLibraryProfiling = false;
          enableExecutableProfiling = false;
        });

        devShells.default = pkgs.mkShell {
          name = "persistent-records-dev";

          packages = with pkgs; [
            hpkgs.cabal-install
            hpkgs.haskell-language-server
            hpkgs.fourmolu
            hpkgs.hlint
            hpkgs.implicit-hie
            hpkgs.ghcid
            hpkgs.ghc
            hpkgs.cabal-add
            hpkgs.hpack
            hpkgs.bindings-libzip
            hpkgs.bzlib
            hpkgs.bzlib-conduit
            hpkgs.bzip2-clib
            hpkgs.postgresql-libpq
            hpkgs.postgresql-libpq-configure
            hpkgs.cabal-hoogle

            haskellPackages.cabal-fmt
            zlib
            zlib.dev
            libz
            pkg-config
            xz
            bzip2
            libzip
            libpq.pg_config
            libpq.dev

            nixd
            statix
            deadnix
            alejandra
            treefmt
            just
            nixd
          ];

          shellHook = ''
            export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${pkgs.postgresql}/lib
          '';
          NIX_CONFIG = "extra-experimental-features = nix-command flakes";
        };
      }
    );
}

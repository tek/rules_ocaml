{
  nixpkgs,
  flake-utils,
  ...
}: { extraInputs ? _: [], depsOpam ? [] }:
let
  main = system: 
  let
    pkgs = import nixpkgs { inherit system; };
    opam = import ./opam.nix { inherit pkgs depsOpam; };
  in rec {
    apps = {
      install = {
        type = "app";
        program = "${opam.installDeps}";
      };
    };
    defaultApp = apps.install;
    devShell = pkgs.mkShell {
      buildInputs = with pkgs; extraInputs pkgs ++ [
        bazel
        pkg-config
      ];
      inherit (opam) shellHook;
    };
  };
in flake-utils.lib.eachSystem ["x86_64-linux"] main

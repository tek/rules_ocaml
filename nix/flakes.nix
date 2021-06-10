{
  nixpkgs,
  flake-utils,
  ...
}: args@{
  extraInputs ? _: [],
}:
let
  main = system: 
  let
    pkgs = import nixpkgs { inherit system; };
    opam = import ./opam.nix ({ inherit pkgs; } // args);
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

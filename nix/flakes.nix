{
  nixpkgs,
  flake-utils,
  ...
}: args@{
  extraInputs ? _: [],
  ...
}:
let
  main = system: 
  let
    pkgs = import nixpkgs { inherit system; };

    opam = import ./opam.nix ({ inherit pkgs; } // args);

    installDeps = pkgs.writeScript "install-opam-deps" ''
      nix develop -c ${opam.installDeps}
    '';
  in rec {
    apps = {
      install = {
        type = "app";
        program = "${installDeps}";
      };
    };
    defaultApp = apps.install;
    devShell = pkgs.mkShell {
      buildInputs = with pkgs; extraInputs pkgs ++ [
        autoconf
        automake
        bazel
        gcc
        libtool
        m4
        pkg-config
      ];
      inherit (opam) shellHook;
    };
  };
in flake-utils.lib.eachSystem ["x86_64-linux"] main

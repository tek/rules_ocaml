{
  nixpkgs,
  flake-utils,
  ...
}: args@{
  extraInputs ? _: [],
  ...
}:
let
  opamEnv = pkgs:
  import ./opam.nix ({ inherit pkgs; } // args);

  shell = pkgs:
  pkgs.mkShell {
    buildInputs = with pkgs; extraInputs pkgs ++ [
      autoconf
      automake
      bazel_4
      gcc
      libtool
      m4
      pkg-config
    ];
    inherit (opamEnv pkgs) shellHook;
  };

  main = system: 
  let
    pkgs = import nixpkgs { inherit system; };

    opam = opamEnv pkgs;

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
    devShell = shell pkgs;
  };
in {
  inherit opamEnv shell main;
  systems = flake-utils.lib.eachSystem ["x86_64-linux"] main;
}

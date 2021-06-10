{ pkgs, depsOpam ? [], ... }:
let
  opam = "${pkgs.opam}/bin/opam";

  opamPkg = name: pkgs.writeScript "install-${name}" ''
    installed=$(${opam} show -f installed-version ${name})
    if [[ $installed == '--' ]]
    then
      ${opam} install -y ${name}
    else
      echo ${name} version: $installed
    fi
  '';

installDeps =
  pkgs.writeScript "install-deps" ''
    ${opam} init --no-opamrc --no-setup
    eval $(${opam} env)
    current=$(${opam} switch show)
    if [[ $current != "4.10" ]]
    then
      ${opam} switch create 4.10 ocaml-base-compiler.4.10.2
    fi
    eval $(${opam} env)
    ${opamPkg "ocamlfind"}
    ${pkgs.lib.strings.concatMapStringsSep "\n" opamPkg depsOpam}
  '';

  shellHook = ''
    export OPAMROOT=$PWD/.opam OPAMNO=true
    if [[ ! -d $OPAMROOT ]]
    then
      nix run .#install
    fi
    eval $(${opam} env)
  '';

in {
  inherit opam opamPkg installDeps shellHook;
}

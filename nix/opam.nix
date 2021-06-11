{ pkgs, depsOpam ? [], switch ? "4.10", compiler ? "ocaml-base-compiler.4.10.2", root ? "$PWD/.opam", ... }:
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
    set -e
    ${opam} init --no-opamrc --no-setup --bare
    eval $(${opam} env)
    current=$(${opam} switch show || true)
    if [[ $current != "${switch}" ]]
    then
      ${opam} switch create ${switch} ${compiler}
    fi
    eval $(${opam} env)
    ${opamPkg "ocamlfind"}
    ${pkgs.lib.strings.concatMapStringsSep "\n" opamPkg depsOpam}
  '';

  shellHook = ''
    export OPAMROOT="${root}" OPAMNO=true
    if [[ ! -f $OPAMROOT/config ]]
    then
      if [[ $OPAMROOT != $REALROOT ]]
      then
        mkdir -p $REALROOT
      fi
      nix run .#install
    fi
    eval $(${opam} env)
  '';

in {
  inherit opam opamPkg installDeps shellHook;
}

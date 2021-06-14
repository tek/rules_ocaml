{
  pkgs,
  depsOpam ? [],
  switch ? "4.10",
  compiler ? "ocaml-base-compiler.4.10.2",
  opamRoot ? null,
  localOpam ? false,
  ...
}:
let
  root =
    if opamRoot == null
    then if localOpam then "$PWD/.opam" else "$HOME/.opam"
    else opamRoot;

  opam = "${pkgs.opam}/bin/opam";

  opamPkg = name: pkgs.writeScript "install-${name}" ''
    installed=$(${opam} show -f installed-version ${name})
    if [[ $installed == '--' ]]
    then
      ${opam} install -y ${name}
    else
      echo ">>> ${name} version: $installed"
    fi
  '';

installDeps =
  pkgs.writeScript "install-deps" ''
    set -e
    echo ">>> installing to ${root}..."
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
    if [[ ! -d $OPAMROOT/${switch} ]]
    then
      REALROOT=$(readlink $OPAMROOT)
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

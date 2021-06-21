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

  opamPkg = spec:
  let
    dep = if builtins.isAttrs spec then spec else { name = spec; version = ""; };
  in pkgs.writeScript "install-${dep.name}" ''
    installed=$(${opam} show --switch ${switch} -f installed-version ${dep.name})
    if [[ $installed == '--' ]] || ( [[ $installed != '${dep.version}' ]] && [[ -n "${dep.version}" ]] ) 
    then
      ${opam} install --switch ${switch} -y ${dep.name}.${dep.version}
    else
      echo ">>> ${dep.name} version: $installed"
    fi
  '';

installDeps =
  pkgs.writeScript "install-deps" ''
    set -e
    echo ">>> installing to ${root}..."
    ${opam} init --no-opamrc --no-setup --bare
    eval $(${opam} env)
    if [[ ! -d ${root}/${switch} ]]
    then
      ${opam} switch create ${switch} ${compiler}
      eval $(${opam} env)
    fi
    ${opamPkg "ocamlfind"}
    ${pkgs.lib.strings.concatMapStringsSep "\n" opamPkg depsOpam}
  '';

  shellHook = ''
    export OPAMROOT="${root}" OPAMNO=true
    if [[ ! -d $OPAMROOT/${switch} ]]
    then
      REALROOT=$(readlink $OPAMROOT)
      if [[ -n $REALROOT && $OPAMROOT != $REALROOT ]]
      then
        mkdir -p $REALROOT
      fi
      ${installDeps}
    fi
    eval $(${opam} env)
  '';

in {
  inherit opam opamPkg installDeps shellHook;
}

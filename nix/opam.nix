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

  opamDep = spec:
  if builtins.isAttrs spec then spec else { name = spec; version = ""; };

  opamSpec = spec:
  let dep = opamDep spec;
  in if dep.version == "" then dep.name else "${dep.name}.${dep.version}";

  opamPkg = spec:
  let
    dep = opamDep spec;
  in pkgs.writeScript "install-${dep.name}" ''
    installed=$(${opam} show --switch ${switch} -f installed-version ${dep.name})
    if [[ $installed == '--' ]] || ( [[ $installed != '${dep.version}' ]] && [[ -n "${dep.version}" ]] ) 
    then
      ${opam} install --switch ${switch} -y ${opamSpec spec}
    else
      echo ">>> ${dep.name} version: $installed"
    fi
  '';

  ensureSwitch = ''
    echo ">>> installing to ${root}..."
    ${opam} init --no-opamrc --no-setup --bare
    eval $(${opam} env)
    if [[ ! -d ${root}/${switch} ]]
    then
      ${opam} switch create ${switch} ${compiler}
      eval $(${opam} env)
    fi
    ${opamPkg "ocamlfind"}
  '';

  installDeps =
  pkgs.writeScript "install-deps" ''
    set -e
    ${ensureSwitch}
    opam install --switch ${switch} -y ${pkgs.lib.strings.concatMapStringsSep " " opamSpec depsOpam}
  '';

  installDepsEach =
  pkgs.writeScript "install-deps-each" ''
    set -e
    ${ensureSwitch}
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
  inherit opam opamPkg installDeps installDepsEach shellHook;
}

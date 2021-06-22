load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")
load(
    "@obazl_rules_ocaml//ocaml:rules.bzl",
    "ocaml_library",
    "ocaml_module",
    "ocaml_ns_library",
    "ocaml_signature",
    "ppx_library",
    "ppx_module",
    "ppx_executable",
    "ppx_ns_library",
)

def copy_interface(name, out):
    copy_file(
        name = name + "_mli",
        src = name + ".mli",
        out = "__obazl/" + out + ".mli",
    )

def sig_module(name, conf, deps = [], use_ppx = False, **kw):
    name = conf.get("name", name)
    struct = conf.get("mod_src", name + ".ml")
    sig = name if conf.get("sigonly", False) else (
        conf.get("sig_name", name + "__sig" if conf.get("sig", False) else None)
    )
    all_deps = deps + conf.get("deps", [])
    if sig != None:
        ocaml_signature(
            name = sig,
            src = conf.get("sig_src", name + ".mli"),
            deps = all_deps + conf.get("sig_deps", []),
            **kw,
        )
    cons = ppx_module if use_ppx else ocaml_module
    kw.update(conf.get("mod_kw", dict()))
    if not conf.get("sigonly"):
        cons(
            name = name,
            struct = struct,
            deps = all_deps + conf.get("mod_deps", []),
            sig = sig,
            **kw,
        )
    return ":" + name

def ppx_exe(name, deps):
    deps_opam = [d for d in deps if not d.startswith("//")]
    deps = [d for d in deps if d.startswith("//")]
    ppx_executable(
        name = "ppx_" + name,
        deps_opam = deps_opam,
        deps = deps,
        main = "@obazl_rules_ocaml//dsl:ppx_driver",
    )

def ppx_args(name):
    return dict(
        ppx = ":ppx_" + name,
        ppx_print = "@ppx//print:text",
    )

def wrapped_lib(name, targets, ppx = False):
    cons_wrapped = ppx_ns_library if ppx else ocaml_ns_library
    wrapped_name = "#" + name.capitalize().replace("-", "_")
    cons_wrapped(
        name = wrapped_name,
        submodules = targets,
        visibility = ["//visibility:public"],
    )

def unwrapped_lib(name, targets, ppx = False):
    cons_unwrapped = ppx_library if ppx else ocaml_library
    unwrapped_name = "lib-" + name
    cons_unwrapped(
        name = unwrapped_name,
        modules = targets,
        visibility = ["//visibility:public"],
    )

def module_set(name, modules, ppx = [], ppx_deps = False, **kw):
    use_ppx = ppx_deps or ppx
    kw.update(use_ppx = use_ppx)
    if ppx:
        ppx_exe(name, ppx)
        kw.update(ppx_args(name))
    return [sig_module(mod_name, conf, **kw) for (mod_name, conf) in modules.items()]

def lib(name, modules, wrapped = True, ppx = [], ppx_deps = False, deps = [], extra_modules = [], **kw):
    use_ppx = ppx_deps or ppx
    main_targets = module_set(
        name,
        modules,
        ppx = ppx,
        ppx_deps = ppx_deps,
        deps = deps + extra_modules,
        **kw,
    )
    targets = main_targets + extra_modules
    wrapped_lib(name, targets, ppx = use_ppx)
    if not wrapped:
        unwrapped_lib(name, targets, ppx = use_ppx)

def simple_lib(modules, sig = True, **kw):
    targets = dict([(name, dict(deps = deps, sig = sig)) for (name, deps) in modules.items()])
    return lib(targets, **kw)

def sig(*deps, **kw):
    return dict(sig = True, deps = list(deps), **kw)

def mod(*deps, **kw):
    return dict(deps = list(deps), **kw)

def sigonly(*deps, **kw):
    return dict(sig = True, sigonly = True, deps = list(deps), **kw)

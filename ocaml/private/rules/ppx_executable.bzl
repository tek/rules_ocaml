load("//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxBinaryProvider",
     "PpxModuleProvider")
load("//ocaml/private/actions:ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_compile",
     "ocaml_ppx_library_link")
load("//ocaml/private:deps.bzl", "get_all_deps")
load("//ocaml/private:utils.bzl",
     "xget_all_deps",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

#############################################
####  PPX_EXECUTABLE IMPLEMENTATION
def _ppx_executable_impl(ctx):

  debug = False
  # if (ctx.label.name == "vector_ffi_bindings.cm_"):
  #     debug = True

  if debug:
      print("PPX_EXECUTABLE TARGET: %s" % ctx.label.name)

#   dep_labels = [dep.label for dep in ctx.attr.build_deps]
#   if Label("@opam//pkg:ppxlib.runner") in dep_labels:
#     if not "-predicates" in ctx.attr.opts:
#       print("""\n\nWARNING: target '{target}' depends on
# '@opam//pkg:ppxlib.runner' but lacks -predicates option. PPX binaries that depend on this
# usually pass \"-predicates\", \"ppx_driver\" to opts. Without this option, the binary may
# compile but may not work as intended.\n\n""".format(target = ctx.label.name))
#   else:
#     print("""\n\nWARNING: ppx_executable target '{target}'
# does not have a driver dependency.  Such targets usually depend on '@opam//pkg:ppxlib.runner'
# or a similar PPX driver. Without a driver, the target may compile but not work as intended.\n\n""".format(target = ctx.label.name))

  # print("PPX BINARY: %s" % ctx.label.name)
  # for src in ctx.attr.srcs:
    # print("PPX BIN SRC: %s" % src)
    # print("PPX BIN SRC type: %s" % type(src))
    # if PpxModuleProvider in src:
      # print("PPX MODULE PROVIDER: %s" % src[PpxModuleProvider])

  mydeps = xget_all_deps(ctx.attr.build_deps)

  # print("PPX BINARY OPAM DEPS")
  # print(mydeps.opam)
  # print("PPX BINARY NOPAM DEPS")
  # print(mydeps.nopam)

  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  outfilename = ctx.label.name
  outbinary = ctx.actions.declare_file(outfilename)

  args = ctx.actions.args()
  args.add("ocamlopt")
  options = tc.opts + ctx.attr.opts
  args.add_all(options)

  args.add("-o", outbinary)

  build_deps = []
  includes = []
  input_deps = []

  # print("NOPAMS: %s" % mydeps.nopam)
  # we need to add the archive components to inputs, the archive is not enough
  # without these we get "implementation not found"
  for dep in mydeps.nopam.to_list():
    # print("DEP:  %s" % dep)
    if hasattr(dep, "cm"):
      # build_deps.append(dep.cm)
      input_deps.append(dep.cm)
      includes.append(dep.cm.dirname)
    if hasattr(dep, "cmxa"):
      build_deps.append(dep.cmxa)
      includes.append(dep.cmxa.dirname)
  # for dep in ctx.attr.build_deps:
  #   for g in dep[DefaultInfo].files.to_list():
  #     if g.path.endswith(".cmx"):
  #       build_deps.append(g)
  #       includes.append(g.dirname)
  #     if g.path.endswith(".cmxa"):
  #       build_deps.append(g)
  #       includes.append(g.dirname)

  args.add_all(includes, before_each="-I", uniquify = True)

  opam_deps = mydeps.opam.to_list()
  # print("\n\nTarget: {target}\nOPAM deps: {deps}\n\n".format(target=ctx.label.name, deps=opam_deps))

  # opam_labels = [dep.to_list()[0].name for dep in opam_deps]
  opam_labels = [dep.pkg.to_list()[0].name for dep in opam_deps]
  if len(opam_deps) > 0:
    # print("Linking OPAM deps for {target}".format(target=ctx.label.name))
    args.add("-linkpkg")
    for dep in opam_deps:
      # print("OPAM DEP: %s" % dep.pkg.to_list()[0].name)
      # if (dep.pkg.to_list()[0].name != "ppx_deriving.api"):
      #   if (dep.pkg.to_list()[0].name != "ppx_deriving.eq"):
      args.add("-package", dep.pkg.to_list()[0].name)
      # args.add_all([dep.to_list()[0].name for dep in opam_deps], before_each="-package")
  # print("OPAM LABELS: %s" % opam_labels)

  # args.add("-absname")

  # non-ocamlfind-enabled deps:
  # for dep in build_deps:
  #   print("BUILD DEP: %s" % dep)

  # WARNING: don't add build_deps to command line.  For namespaced
  # modules, they may contain both a .cmx and a .cmxa with the same
  # name, which define the same module, which will make the compiler
  # barf.
  # OTOH, if we do not list them, they will not be found when the ppx is used.
  args.add_all(build_deps)

  # driver shim source must come after lib deps!
  args.add_all(ctx.files.srcs)

  dep_graph = build_deps + input_deps + ctx.files.srcs
  # print("DEP_GRAPH:")
  # print(dep_graph)

  output_deps = []
  for dep in ctx.attr.output_deps:
    # print("SEC DEP: %s" % dep[OpamPkgInfo])
    if OpamPkgInfo in dep:
        output_dep = dep[OpamPkgInfo].pkg.to_list()[0]
        output_deps.append(output_dep.name)
        ## opam deps are just strings, we feed them to ocamlfind, which finds the file.
        ## this means we cannot add them to the dep_graph.
        ## this makes sense, the exe we build does not depend on these,
        ## it's the subsequent transform that depends on them.
    else:
        dep_graph.append(dep)
    #FIXME: also support non-opam transform deps

  # print("DEP_GRAPH: %s" % dep_graph)
  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = dep_graph,
    outputs = [outbinary],
    tools = [tc.opam, tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlPPXBinary",
    progress_message = "ppx_executable({}), {}".format(
      ctx.label.name, ctx.attr.message
      )
  )


  # print("PPX_EXECUTABLE TRANSFORM: %s" % output_deps)

  return [DefaultInfo(executable=outbinary,
                      files = depset(direct = [outbinary])),
          PpxBinaryProvider(
            payload=outbinary,
            args = depset(direct = ctx.attr.args),
            deps = struct(
              opam = mydeps.opam,
              nopam = mydeps.nopam,
              ## these are labels of opam deps to be used later:
              transform = output_deps
            )
          )]

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  PPX_EXECUTABLE  ################
ppx_executable = rule(
  implementation = _ppx_executable_impl,
  # implementation = _ppx_executable_compile_test,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    # IMPLICIT: args = string list = runtime args, passed whenever the binary is used
    srcs = attr.label_list(
      allow_files = OCAML_IMPL_FILETYPES
    ),
    ppx_bin  = attr.label(
      doc = "PPX binary (executable).",
      providers = [PpxBinaryProvider]
    ),
    ppx  = attr.label(
      doc = "PPX binary (executable).",
      providers = [PpxBinaryProvider]
    ),
    opts = attr.string_list(),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    build_deps = attr.label_list(
      doc = "Deps needed to build this ppx executable.",
      providers = [[DefaultInfo], [PpxModuleProvider]]
    ),
    output_deps = attr.label_list(
      doc = """List of deps needed to compile output of this ppx transformer. Dune calls these 'runtime' deps.""",
      providers = [[DefaultInfo], [PpxModuleProvider]]
    ),
    mode = attr.string(default = "native"),
    message = attr.string()
  ),
  provides = [DefaultInfo, PpxBinaryProvider],
  executable = True,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)
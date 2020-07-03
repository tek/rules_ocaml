load("@obazl_rules_ocaml//ocaml/private:providers.bzl",
     "OcamlSDK",
     "OpamPkgInfo",
     "PpxInfo")
load("@obazl_rules_ocaml//ocaml/private:actions/ppx.bzl",
     "apply_ppx",
     "ocaml_ppx_compile",
     # "ocaml_ppx_apply",
     "ocaml_ppx_library_gendeps",
     "ocaml_ppx_library_cmo",
     "ocaml_ppx_library_compile",
     "ocaml_ppx_library_link")
load("@obazl_rules_ocaml//ocaml/private:utils.bzl",
     "get_opamroot",
     "get_sdkpath",
     "get_src_root",
     "strip_ml_extension",
     "OCAML_FILETYPES",
     "OCAML_IMPL_FILETYPES",
     "OCAML_INTF_FILETYPES",
     "WARNING_FLAGS"
)

########## RULE:  OCAML_PPX_PIPELINE  ################

####  OCAML_PPX_PIPELINE IMPLEMENTATION
def _ocaml_ppx_pipeline_impl(ctx):
  tc = ctx.toolchains["@obazl_rules_ocaml//ocaml:toolchain"]
  env = {"OPAMROOT": get_opamroot(),
         "PATH": get_sdkpath(ctx)}

  outfilename = ctx.label.name
  outbinary = ctx.actions.declare_file(outfilename)
  lflags = " ".join(ctx.attr.linkopts) if ctx.attr.linkopts else ""

  args = ctx.actions.args()
  # we will pass ocamlfind as the exec arg, so we start args with ocamlopt
  args.add("ocamlopt")
  args.add_all(ctx.attr.opts)
  args.add("-o", outbinary)

  # for wrapper gen:
  # args.add("-w", "-24")

  ## findlib says:
  ## "If you want to create an executable, do not forget to add the -linkpkg switch."
  # http://projects.camlcity.org/projects/dl/findlib-1.8.1/doc/QUICKSTART
  # args.add("-linkpkg")
  # args.add("-linkall")

  build_deps = []
  includes = []

  for dep in ctx.attr.deps:
    if OpamPkgInfo in dep:
      args.add("-package", dep[OpamPkgInfo].pkg)
      # build_deps.append(dep[OpamPkgInfo].pkg)
    else:
      for g in dep[DefaultInfo].files.to_list():
        if g.path.endswith(".cmx"):
          args.add(g)
          build_deps.append(g)
          includes.append(g.dirname)
        if g.path.endswith(".cmxa"):
          args.add(g)
          build_deps.append(g)
          includes.append(g.dirname)
      # if PpxInfo in dep:
      #   print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
      #   build_deps.append(dep[PpxInfo].cmxa)
      #   build_deps.append(dep[PpxInfo].a)
      # else:
      #   print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
      #   for g in dep[DefaultInfo].files.to_list():
      #     print(g)
      #     if g.path.endswith(".cmx"):
      #       build_deps.append(g)
      #       args.add("-I", g.dirname)

  args.add_all(includes, before_each="-I", uniquify = True)

  # for ocamlfind-enabled deps, use -package
  # args.add_joined("-package", build_deps, join_with=",")

  # non-ocamlfind-enabled deps:

  args.add_all(ctx.files.srcs)

  inputs = build_deps + ctx.files.srcs
  # print("INPUTS:")
  # print(inputs)

  ctx.actions.run(
    env = env,
    executable = tc.ocamlfind,
    arguments = [args],
    inputs = inputs,
    outputs = [outbinary],
    tools = [tc.opam, tc.ocamlfind, tc.ocamlopt],
    mnemonic = "OcamlPPXBinary",
    progress_message = "ocaml_ppx_pipeline({}), {}".format(
      ctx.label.name, ctx.attr.message
      )
  )

  return [DefaultInfo(executable=outbinary,
                      files = depset(direct = [outbinary])),
          PpxInfo(ppx=outbinary)]
# OutputGroupInfo(bin = depset([bin_output]))]

# (library
#  (name deriving_hello)
#  (libraries base ppxlib)
#  (preprocess (pps ppxlib.metaquot))
#  (kind ppx_deriver))

#############################################
########## DECL:  OCAML_PPX_PIPELINE  ################
ocaml_ppx_pipeline = rule(
  implementation = _ocaml_ppx_pipeline_impl,
  attrs = dict(
    _sdkpath = attr.label(
      default = Label("@ocaml//:path")
    ),
    opts = attr.string_list(),
    linkopts = attr.string_list(),
    linkall = attr.bool(default = True),
    srcs = attr.label_list(
      allow_files = OCAML_IMPL_FILETYPES
    ),
    deps = attr.label_list(
      # providers = [OpamPkgInfo]
    ),
    mode = attr.string(default = "native"),
    message = attr.string()
  ),
  provides = [DefaultInfo, OutputGroupInfo, PpxInfo],
  executable = True,
  toolchains = ["@obazl_rules_ocaml//ocaml:toolchain"],
)

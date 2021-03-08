## ocaml/_rules/impl_common.bzl

load("//ocaml:providers.bzl",
     "AdjunctDepsProvider",
     "CcDepsProvider",
     "CompilationModeSettingProvider",
     "DefaultMemo",
     "OcamlArchiveProvider",
     "OcamlSignatureProvider",
     "OcamlLibraryProvider",
     "OcamlModuleProvider",
     "OcamlNsResolverProvider",
     "OcamlNsLibraryProvider",
     "OpamDepsProvider")

tmpdir = "_obazl_/"

#########################################
def merge_deps(deps,
               indirect_file_depsets,
               indirect_path_depsets,
               indirect_resolver_depsets,
               indirect_opam_depsets,
               indirect_adjunct_depsets,
               indirect_adjunct_path_depsets,
               indirect_adjunct_opam_depsets,
               indirect_cc_deps):

    ccdeps_labels = {}
    ccdeps = {}

    for dep in deps:

        indirect_file_depsets.append(dep[DefaultInfo].files)
        indirect_path_depsets.append(dep[DefaultMemo].paths)

        if OcamlNsResolverProvider in dep:
            if hasattr(dep[OcamlNsResolverProvider], "files"):
                indirect_file_depsets.append(dep[OcamlNsResolverProvider].files)
                paths = []
                for file in dep[OcamlNsResolverProvider].files.to_list():
                    paths.append(file.dirname)
                indirect_path_depsets.append(
                    depset(direct = paths)
                )
                indirect_resolver_depsets.append(
                    depset(direct = [dep[OcamlNsResolverProvider].resolver])
                )

        ## FIXME: use OcamlNsResolverProvider to pass resolvers
        indirect_resolver_depsets.append(dep[DefaultMemo].resolvers)

        if AdjunctDepsProvider in dep:
            indirect_adjunct_depsets.append(dep[AdjunctDepsProvider].nopam)
            indirect_adjunct_path_depsets.append(dep[AdjunctDepsProvider].nopam_paths)
            indirect_adjunct_opam_depsets.append(dep[AdjunctDepsProvider].opam)

        if OpamDepsProvider in dep:
            indirect_opam_depsets.append(dep[OpamDepsProvider].pkgs)

        if CcDepsProvider in dep:
            # if len(dep[CcDepsProvider].libs) > 0:
                # print("CCDEPS for %s" % dep)
            # for ccdict in dep[CcDepsProvider].libs:
            for [dep, linkmode] in dep[CcDepsProvider].libs.items():  ## ccdict.items():
                if dep.label in ccdeps_labels.keys():
                    if linkmode != ccdeps_labels[dep.label]:
                        fail("CCDEP: same key {k}, different vals: {v1}, {v2}".format(
                            k = dep,
                            v1 = ccdeps_labels[dep.label], v2 = linkmode
                        ))
                    # else:
                    #     print("Removing DUP ccdep: {k}: {v}".format(
                    #         k = dep, v = linkmode
                    #     ))
                else:
                    ccdeps_labels.update({dep.label: linkmode})
                    ccdeps.update({dep: linkmode})
            indirect_cc_deps.update(ccdeps)

    # if len(indirect_cc_deps) > 0:
    #     print("INDIRECT_CC_DEPS out: %s" % indirect_cc_deps)
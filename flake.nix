{
  description = "Bazel Rules for OCaml";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-utils.url = github:numtide/flake-utils;
  };

  outputs = inputs:
  rec {
    opam = import ./nix/opam.nix;
    flakes = import ./nix/flakes.nix inputs;
    systems = args: (flakes args).systems;
  };
}

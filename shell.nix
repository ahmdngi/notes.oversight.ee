# Needed for nixos for developement. sets nix-shell to use mkdocs serve
{ pkgs ? import <nixpkgs> {} }:

let
  my-python-packages = ps: with ps; [
    mkdocs-material
    mkdocs-glightbox
    mkdocs-minify-plugin
#    search
  ];
in

pkgs.mkShell {
  packages = [
    (pkgs.python3.withPackages my-python-packages)
  ];
}

{ pkgs ? import <nixpkgs> {} }:

let
  my-python-packages = ps: with ps; [
    mkdocs-material
    mkdocs-glightbox
    mkdocs-minify
#    search
  ];
in

pkgs.mkShell {
  packages = [
    (pkgs.python3.withPackages my-python-packages)
  ];
}

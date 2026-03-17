# Needed for local development. Sets nix-shell up for `zensical serve`.
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = [
    (pkgs.zensical.overridePythonAttrs (old: {
      propagatedBuildInputs =
        (old.propagatedBuildInputs or [])
        ++ (with pkgs.python3Packages; [
          mkdocs-glightbox
          mkdocs-minify-plugin
        ]);
    }))
  ];
}

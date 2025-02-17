{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.python3
    pkgs.python3Packages.python-lsp-server
    pkgs.python3Packages.python-lsp-ruff   # Linter
    pkgs.python3Packages.python-lsp-black  # Formatter
  ];
}

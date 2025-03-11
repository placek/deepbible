{ pkgs ? (import (builtins.fetchTarball { url = "https://github.com/NixOS/nixpkgs/archive/21808d22b1cda1898b71cf1a1beb524a97add2c4.tar.gz"; }) {})
}:
pkgs.mkShell {
  buildInputs = with pkgs; [
    sqlite
    sqlite-vec
    rlwrap
    sqlitebrowser

    python3
    python3Packages.requests
    python3Packages.beautifulsoup4
    python3Packages.lxml
    python3Packages.numpy
    python3Packages.sentence-transformers
  ];
  shellHook = ''
    export SQLITE_VEC_PATH=${pkgs.sqlite-vec}/lib/vec0.so
    export MODEL_NAME=sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
  '';
}

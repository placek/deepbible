{ pkgs ? (import (builtins.fetchTarball { url = "https://github.com/NixOS/nixpkgs/archive/21808d22b1cda1898b71cf1a1beb524a97add2c4.tar.gz"; }) {})
}:
pkgs.mkShell {
  buildInputs = with pkgs; [
    sqlite
    rlwrap
    sqlitebrowser
    p7zip
    postgresql

    python3
    python3Packages.psycopg2
    python3Packages.requests
    python3Packages.tqdm
  ];
}

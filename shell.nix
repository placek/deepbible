{ pkgs ? (import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/21808d22b1cda1898b71cf1a1beb524a97add2c4.tar.gz";
  }) {})
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  frontendFlake = builtins.getFlake (toString ./frontend);
  frontendShell = frontendFlake.devShells.${system}.default;
in
pkgs.mkShell {
  # Pull in every tool declared for the frontend devShell so both root and frontend shells match.
  inputsFrom = [ frontendShell ];

  buildInputs = with pkgs; [
    sqlite
    rlwrap
    sqlitebrowser
    pgloader
    pgformatter
    postgresql
    p7zip
  ];

  shellHook = ''
    alias watch="find src | entr -s 'echo bundling; purs-nix bundle'"
  '';
}

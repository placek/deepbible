{ pkgs ? (import <nixpkgs> {})
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  frontendFlake = builtins.getFlake (toString ./frontend);
  frontendShell = frontendFlake.devShells.${system}.default;
in
pkgs.mkShell {
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
}

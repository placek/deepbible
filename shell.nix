{ pkgs ? (import <nixpkgs> {})
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

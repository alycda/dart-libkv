{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.dart
    pkgs.just
  ];
  
  shellHook = ''
    echo "Dart development environment loaded"
  '';
}
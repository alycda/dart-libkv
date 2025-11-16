{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.dart
  ];
  
  shellHook = ''
    echo "Dart development environment loaded"
  '';
}
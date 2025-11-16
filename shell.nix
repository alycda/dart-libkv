{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.dart
    pkgs.just
    pkgs.presenterm
  ];
  
  shellHook = ''
    echo "Dart development environment loaded"
  '';
}
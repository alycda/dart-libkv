{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.dart
    pkgs.just
    pkgs.presenterm
  ];
  
  shellHook = ''
    echo "Dart development environment loaded"
    # Ensure dependencies are fetched
    if [ -f pubspec.yaml ]; then
      dart pub get
    fi
  '';
}
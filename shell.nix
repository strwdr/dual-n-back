{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "dual-n-back-dev";

  packages = with pkgs; [
    godot_4
    godot_4-export-templates-bin
  ];
}

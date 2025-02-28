{
  modFolder,
  loadFolder,
  lib,
}: let
  lsDirs = folder: (builtins.attrNames (lib.filterAttrs (_n: v: v == "directory") (builtins.readDir folder)));
  modNames = lsDirs modFolder;
in
  {
    config,
    lib,
    # deadnix: skip
    pkgs,
    # deadnix: skip
    inputs,
    ...
  } @ args: {
    options.modules = builtins.listToAttrs (
      map
      (
        x: {
          name = x;
          value = {enable = lib.mkEnableOption "${x} mod";};
        }
      )
      modNames
    );
    config = lib.mkMerge (
      map
      (
        x: lib.mkIf config.modules.${x}.enable ((loadFolder (modFolder + "/${x}")) args)
      )
      modNames
    );
  }

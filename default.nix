{
  haumea,
  lib,
}: let
  # deadnix: skip
  loadFolder = folder: ({pkgs, ...} @ args:
    haumea.lib.load {
      src = folder;
      inputs = args;
      transformer = haumea.lib.transformers.liftDefault;
    });

  ls = folder: (builtins.attrNames (builtins.readDir folder));

  mods = modFolder: import ./modules.nix {inherit lib modFolder loadFolder;};
in rec {
  inherit loadFolder;
  makeNixosSystem = {
    flakeRoot,
    hostFolder,
    commonFolder ? flakeRoot + "/common",
    modFolder ? flakeRoot + "/modules",
    name,
    specialArgs ? {},
    defaultSystem ? null,
  }: let
    systemPath = hostFolder + "/${name}/_localSystem.nix";
    system =
      if builtins.pathExists systemPath
      then (import systemPath)
      else
        (
          if defaultSystem != null
          then defaultSystem
          else (abort "Neither host '${name}' or 'defaultSystem' have an architecture set")
        );

    hostCfg = loadFolder (hostFolder + "/${name}");
  in
    lib.nixosSystem {
      inherit system specialArgs;
      modules = [
        hostCfg
        (loadFolder commonFolder)
        (mods modFolder)
        {networking.hostName = name;}
      ];
    };

  makeNixosSystems = {flakeRoot, hostFolder ? flakeRoot + "/hosts", ...} @ args:
    builtins.listToAttrs
    (
      map
      (name: {
        inherit name;
        value = makeNixosSystem (args
          // {
            inherit name hostFolder;
          });
      })
      (ls hostFolder)
    );

  getHomes = homeFolder:
    builtins.listToAttrs
    (
      map
      (name: {
        inherit name;
        value = loadFolder (homeFolder + "/${name}");
      })
      (ls homeFolder)
    );

  multinix = inputs: rec {
    nixosConfigurations = let
      homes = getHomes "${inputs.self}/home";
      flakeLib = haumea.lib.load {
        src = "${inputs.self}/lib";
        inputs = {inherit inputs; };
      transformer = haumea.lib.transformers.liftDefault;
      };
    in makeNixosSystems {
      flakeRoot = inputs.self;
      specialArgs = {inherit inputs homes flakeLib; };
    };

    hydraJobs = {
      inherit (inputs.self.outputs) devShells;
      nixos = builtins.mapAttrs (_name: value: value.config.system.build.toplevel) nixosConfigurations;
    };
  };
}

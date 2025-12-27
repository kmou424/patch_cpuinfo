{
  description = "patch_cpuinfo - Kernel module to patch CPU model name";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        # Build the kernel module for the current kernel
        # This will be used by NixOS module
        patch-cpuinfo-kmod = pkgs.linuxPackages.callPackage (
          {
            stdenv,
            kernel,
          }:
          stdenv.mkDerivation {
            pname = "patch_cpuinfo";
            version = "1.0.0-${kernel.modDirVersion}";

            src = ./.;

            nativeBuildInputs = with pkgs; [
              bc
              kmod
            ];

            buildInputs = [ kernel.dev ];

            buildPhase = ''
              runHook preBuild
              make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build M=$(pwd) modules
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
              cp patch_cpuinfo.ko $out/lib/modules/${kernel.modDirVersion}/extra/
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Kernel module to patch CPU model name via sysfs";
              homepage = "https://github.com/kmou424/patch_cpuinfo";
              license = licenses.gpl2Only;
              maintainers = [ ];
              platforms = platforms.linux;
            };
          }
        ) { };
      in
      {
        packages = {
          default = patch-cpuinfo-kmod;
          patch-cpuinfo = patch-cpuinfo-kmod;
        };

        nixosModules = {
          default = import ./modules/patch-cpuinfo.nix;
          patch-cpuinfo = import ./modules/patch-cpuinfo.nix;
        };
      }
    )
    // {
      nixosModules = {
        default = import ./modules/patch-cpuinfo.nix;
        patch-cpuinfo = import ./modules/patch-cpuinfo.nix;
      };
    };
}

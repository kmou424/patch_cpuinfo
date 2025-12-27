{
  config,
  lib,
  pkgs,
  ...
}@args:

with lib;

let
  cfg = config.hardware.patch-cpuinfo;
  inputs = args.inputs or null;
  system = pkgs.system or config.nixpkgs.system or "x86_64-linux";

  # Try to get package from flake input first
  # This is the preferred method as it uses the pre-built package from the flake
  # However, we need to check if the kernel version matches the system kernel
  flakePackage =
    if inputs != null && inputs ? patch-cpuinfo then
      let
        input = inputs.patch-cpuinfo;
        systemKernelVersion = config.boot.kernelPackages.kernel.modDirVersion;
        # Try to get the package
        candidatePackage =
          if builtins.hasAttr "packages" input && builtins.hasAttr system input.packages then
            if builtins.hasAttr "patch-cpuinfo" input.packages.${system} then
              input.packages.${system}.patch-cpuinfo
            else if builtins.hasAttr "default" input.packages.${system} then
              input.packages.${system}.default
            else
              null
          else
            null;
        # Check if the package's kernel version matches the system kernel version
        # We can't easily check this at evaluation time, so we'll skip flake package
        # and always use auto-build to ensure kernel version matches
      in
      # Skip flake package to avoid kernel version mismatch
      # Always build for the current system kernel to ensure compatibility
      null
    else
      null;

  # Try to get source from inputs, or use a relative path as fallback
  # For flake inputs, we need to use the source path properly
  moduleSrc =
    if inputs != null && inputs ? patch-cpuinfo then
      # For flake inputs, try to get the source path
      # Flake inputs have different structures, try common patterns
      let
        input = inputs.patch-cpuinfo;
      in
      if builtins.isPath input then
        input
      else if builtins.hasAttr "outPath" input then
        input.outPath
      else if builtins.hasAttr "sourceInfo" input && builtins.hasAttr "outPath" input.sourceInfo then
        input.sourceInfo.outPath
      else
        # Last resort: try to use the input directly (may fail, but will give a better error)
        throw
          "patch-cpuinfo: Unable to determine source path from flake input. Please specify hardware.patch-cpuinfo.package explicitly."
    else
      # Fallback: try to find the source relative to this module
      # This assumes the module is in tmp/patch_cpuinfo/modules/
      ../../.;

  # Build the kernel module for the current kernel
  # Only build if package is not explicitly provided and flake package is not available
  patch-cpuinfo-module =
    if cfg.package == null && flakePackage == null then
      config.boot.kernelPackages.callPackage (
        {
          stdenv,
          kernel,
        }:
        stdenv.mkDerivation {
          pname = "patch_cpuinfo";
          version = "1.0.0-${kernel.modDirVersion}";

          src = moduleSrc;

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
      ) { }
    else
      null;
in
{
  options.hardware.patch-cpuinfo = {
    enable = mkEnableOption "patch_cpuinfo kernel module";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        The patch-cpuinfo kernel module package to use.
        If null, the module will try to use the package from inputs.patch-cpuinfo.packages,
        or build it automatically for the current kernel if the flake package is not available.
        You can override this to use a custom package.
      '';
    };

    modelName = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "Intel(R) Core(TM) i9-13900T ES";
      description = ''
        CPU model name to set via sysfs.
        If set, a systemd service will write this value to /sys/kernel/patch_cpuinfo/model_name on boot.
        If null, the module will be loaded but no model name will be set automatically.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Add the kernel module to extraModulePackages
    # Priority: 1. explicitly provided package, 2. flake package, 3. auto-built module
    boot.extraModulePackages =
      if cfg.package != null then
        [ cfg.package ]
      else if flakePackage != null then
        [ flakePackage ]
      else if patch-cpuinfo-module != null then
        [ patch-cpuinfo-module ]
      else
        throw "patch-cpuinfo: Unable to build kernel module. Please specify hardware.patch-cpuinfo.package or ensure inputs.patch-cpuinfo is available.";

    # Load the module on boot
    boot.kernelModules = [ "patch_cpuinfo" ];

    # If modelName is set, create a systemd service to write it on boot
    systemd.services.patch-cpuinfo = mkIf (cfg.modelName != null) {
      description = "Set CPU model name via patch_cpuinfo";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      requires = [ "systemd-modules-load.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Check if module is loaded, and set the model name if available
        # If module is not loaded (e.g., during nixos-rebuild switch), just log a warning
        ExecStart = pkgs.writeShellScript "patch-cpuinfo-set" ''
          # Check if module is loaded
          if ! ${pkgs.kmod}/bin/lsmod | grep -q "^patch_cpuinfo "; then
            echo "Warning: patch_cpuinfo module is not loaded. Model name will be set when module is loaded at boot." >&2
            exit 0
          fi

          # Try to set model name once
          if [ -f /sys/kernel/patch_cpuinfo/model_name ]; then
            echo "${cfg.modelName}" > /sys/kernel/patch_cpuinfo/model_name
            echo "Successfully set CPU model name to: ${cfg.modelName}"
            exit 0
          else
            echo "Warning: /sys/kernel/patch_cpuinfo/model_name not found" >&2
            exit 0
          fi
        '';
        # Don't fail the service if module is not loaded
        StandardError = "journal";
      };
    };
  };
}

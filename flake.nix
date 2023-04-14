{
  description = "A hex editor";

  # https://github.com/NixOS/nixpkgs/blob/nixos-22.11/pkgs/applications/editors/imhex/default.nix
  # https://github.com/WerWolv/ImHex/blob/master/dist/Brewfile
  # https://github.com/WerWolv/ImHex/blob/master/dist/compiling/macos.md

  # Does not work due to submodules not supported; Checkout manually
  # and use --override-input with local dir if you want to build from
  # git
  #
  #inputs.source.url = "github:WerWolv/ImHex";
  inputs.source.url = "https://github.com/WerWolv/ImHex/releases/download/v1.28.0/Full.Sources.tar.gz";
  inputs.source.flake = false;

  inputs.patterns_src.url = "github:WerWolv/ImHex-Patterns";
  inputs.patterns_src.flake = false;

  outputs = { self, nixpkgs, source, patterns_src }:
    let
      pkgs = import nixpkgs { system = "x86_64-darwin"; };
    in
      {
        packages.x86_64-darwin.default = pkgs.stdenv.mkDerivation {
          name = "imhex";
          version = "1.28.0";
          src = source;
          buildInputs = with pkgs; [mbedtls nlohmann_json freetype glfw file fmt_8 curl yara jansson darwin.apple_sdk_10_12.frameworks.AppKit];
          nativeBuildInputs = with pkgs; [cmake llvmPackages_15.clangUseLLVM gcc12 pkg-config llvm ninja];
          cmakeFlags = [
            "-DIMHEX_OFFLINE_BUILD=ON"
            # see comment at the top about our version of capstone
            "-DUSE_SYSTEM_CAPSTONE=OFF"
            "-DUSE_SYSTEM_CURL=ON"
            "-DUSE_SYSTEM_FMT=OFF"
            "-DUSE_SYSTEM_LLVM=OFF"
            "-DUSE_SYSTEM_NLOHMANN_JSON=ON"
            "-DUSE_SYSTEM_YARA=ON"

            "-DCMAKE_BUILD_TYPE=Release"
            "-DCREATE_BUNDLE=OFF" # Does not work for now
            "-DCREATE_PACKAGE=OFF"

            "-DCMAKE_C_COMPILER=${pkgs.gcc12}/bin/gcc"
            "-DCMAKE_CXX_COMPILER=${pkgs.gcc12}/bin/g++"
            "-DCMAKE_OBJC_COMPILER=${pkgs.llvmPackages_15.clangUseLLVM}/bin/clang"
            "-DCMAKE_OBJCXX_COMPILER=${pkgs.llvmPackages_15.clangUseLLVM}/bin/clang++"

            "-DCMAKE_OSX_DEPLOYMENT_TARGET=10.12"
            "-DCMAKE_OSX_ARCHITECTURES=x86_64"

            "-DIMHEX_PLUGINS_IN_SHARE=ON"
            "-DIMHEX_OFFLINE_BUILD=ON"
          ];

          # Install cmake target does not work correctly, it only
          # copies binary to root directory and not libs
          #
          # TODO: https://duerrenberger.dev/blog/2021/08/04/understanding-rpath-with-cmake/
          #
          # TODO: make it recognize plugins in share
          #
          # TODO: try to use CMAKE_MACOSX_RPATH, CMAKE_INSTALL_RPATH
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            mkdir -p $out/lib
            mkdir -p $out/share/imhex
            install_name_tool -add_rpath "$out/lib" imhex
            cp imhex $out/bin/
            cp lib/libimhex/libimhex.dylib $out/lib/
            cp -r plugins $out/share/imhex
            ln -s $out/share/imhex/plugins $out/bin/
            for d in ${patterns_src}/{constants,encodings,includes,magic,patterns}; do
              cp -r $d $out/share/imhex/
            done
            runHook postInstall
          '';
        };
      };
}

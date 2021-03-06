{ cc ? "gcc7", nixpkgs ? import ../nixpkgs.nix }:

let
  crossSystem = {
    config = "riscv32-elf";
    libc = "newlib";

    platform = {
      bfdEmulation = "elf32lriscv";
      gcc = {
        arch = "rv32imac";
      };
    };
  };

  pkgs = nixpkgs {
    inherit crossSystem;
  };

  stdenv = pkgs.stdenv.override {
    cc = pkgs.buildPackages.${cc};
  };

  inherit (pkgs.buildPackages) autoreconfHook fetchgit gdb lib python3
    screen writeShellScriptBin;

  openocd = pkgs.buildPackages.openocd.overrideAttrs (super: {
    nativeBuildInputs = [ autoreconfHook ] ++ super.nativeBuildInputs;
    src = fetchgit {
      url = https://github.com/riscv/riscv-openocd;
      rev = "c554246177bb8b2b03ca584847c4ffc2b2f7bb4b";
      sha256 = "1fvi4b1fjrbsiwpmdbc9rm7ajx521d9v1b8qhrjnzg9dhvg0mf0w";
    };
  });

  PREFIX = stdenv.hostPlatform.config;

  upload = writeShellScriptBin "upload" ''
    GDB_PORT=3333
    ${openocd}/bin/openocd -s sdk -f openocd.cfg &
    ${gdb}/bin/${PREFIX}-gdb "$1" --batch \
      -ex "set remotetimeout 240" \
      -ex "target extended-remote localhost:$GDB_PORT" \
      -ex "monitor reset halt" \
      -ex "monitor flash protect 0 64 last off" \
      -ex "load" \
      -ex "monitor resume" \
      -ex "monitor shutdown" \
      -ex "quit"
  '';

in stdenv.mkDerivation {
  name = "thesis";
  inherit PREFIX;
  nativeBuildInputs = [ openocd python3 screen upload ];
}

{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
          ];

          shellHook = ''
          '';
        };

  };
}

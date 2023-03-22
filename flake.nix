{
  description = "An over-engineered autozsnap.sh script ";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-22.11";

  outputs = { self, nixpkgs }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        autozsnap = with final; stdenv.mkDerivation rec {
          name = "autozsnap-${version}";
          src = ./.;

          #unpackPhase = ":";

          buildPhase =
            ''
              chmod +x autozsnap.sh
            '';

          installPhase =
            ''
              mkdir -p $out/bin $out/share
              install autozsnap.sh $out/bin/ 
              ln -s $out/bin/autozsnap.sh $out/bin/autozsnap
            '';
        };

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) autozsnap;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.autozsnap);

      # A NixOS module, if applicable (e.g. if the package provides a system service).
      nixosModules.autozsnap =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];

          environment.systemPackages = [ pkgs.autozsnap ];

          #systemd.services = { ... };
        };

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems
        (system:
          with nixpkgsFor.${system};

          {
            inherit (self.packages.${system}) autozsnap;

            # Additional tests, if applicable.
            test = stdenv.mkDerivation {
              name = "autozsnap-test-${version}";

              buildInputs = [ autozsnap shellcheck ];

              unpackPhase = "true";

              buildPhase = ''
                echo 'running some integration tests'
                [[ $(shellcheck ${autozsnap}/bin/autozsnap) ]]
              '';

              installPhase = "mkdir -p $out";
            };
          }

          // lib.optionalAttrs stdenv.isLinux {
            # A VM test of the NixOS module.
            vmTest =
              with import (nixpkgs + "/nixos/lib/testing-python.nix")
                {
                  inherit system;
                };

              makeTest {
                name = "vmTest";
                nodes = {
                  client = { ... }: {
                    imports = [ self.nixosModules.autozsnap ];
                  };
                };

                testScript =
                  ''
                    start_all()
                    client.wait_for_unit("multi-user.target")
                    #client.succeed("autozsnap")
                  '';
              };
          }
        );

    };
}

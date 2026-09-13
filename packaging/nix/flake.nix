{
  description = "Antigravity Multi-Account Token, Quota & Tier Bulk Checker";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pythonPackages = pkgs.python3Packages;
      in
      {
        packages.default = pythonPackages.buildPythonApplication {
          pname = "agy-quota";
          version = "1.2.0";
          src = ./../..;

          propagatedBuildInputs = [
            pythonPackages.cryptography
            pythonPackages.rich
            pythonPackages.setuptools
          ];

          doCheck = false;

          meta = with pkgs.lib; {
            description = "Antigravity Multi-Account Token, Quota & Tier Bulk Checker";
            homepage = "https://github.com/zyekhabdul/agy-quota";
            license = licenses.mit;
            maintainers = [ "zyekhabdul" ];
          };
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
        };
      }
    );
}

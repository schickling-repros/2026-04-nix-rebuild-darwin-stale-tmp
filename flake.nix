{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
    in {
      packages = builtins.listToAttrs (map
        (system: {
          name = system;
          value = let
            pkgs = import nixpkgs { inherit system; };
          in {
            multi = pkgs.runCommand "darwin-rebuild-stale-tmp" {
              outputs = [ "out" "dev" ];
            } ''
              mkdir -p "$out/tree" "$dev/tree"
              printf '%s\n' "$out" > "$dev/tree/out-path.txt"
              ln -s "$out/tree" "$dev/tree/out-tree.link"
              i=0
              while [ "$i" -lt 20000 ]; do
                printf '%08d\n' "$i" > "$out/tree/file-$i.txt"
                i=$((i + 1))
              done
            '';
          };
        })
        systems);
    };
}

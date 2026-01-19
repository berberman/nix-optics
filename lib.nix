{
  # https://github.com/nix-community/nixpkgs.lib/blob/78975aaec5a67ea502e15836919b89d7df96ac27/lib/lists.nix
  foldr =
    op: nul: list:
    let
      len = builtins.length list;
      fold' = n: if n == len then nul else op (builtins.elemAt list n) (fold' (n + 1));
    in
    fold' 0;

  updateAt =
    index: val: list:
    let
      len = builtins.length list;
    in
    if index < 0 || index >= len then
      list
    else
      builtins.genList (n: if n == index then val else builtins.elemAt list n) len;
}

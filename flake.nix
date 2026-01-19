{
  description = "nix-optics";

  outputs =
    { self }:
    {
      lib = import ./default.nix;
    };
}

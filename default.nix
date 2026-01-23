let
  lib = import ./lib.nix;
  classes = import ./classes.nix { inherit lib; };
  optics = import ./optics.nix { inherit lib classes; };
  inherit (classes) functors profunctors monoids;
in
rec {
  inherit lib classes;

  # over :: Lens s t a b -> (a -> b) -> s -> t
  #      :: (forall p. Strong p => (Dict p -> p a b) -> (Dict p -> p s t)) -> (a -> b) -> s -> t
  # Here we instantiate 'p' with (->) (Function arrow).
  # Then feeding (Dict Arrow -> (a -> b)) to 'optic' gives us (Dict Arrow -> (s -> t))
  over =
    # optic :: Optic s t a b
    # f :: a -> b
    optic: f: optic (_P: f) profunctors.Arrow;

  # set :: Lens s t a b -> b -> s -> t
  set = optic: val: over optic (_: val);

  # toListOf :: (forall p. Traversing p => Optic p s t a b) -> s -> [a]
  # Here we instantiate 'p' with Forget [a], i.e. Star (Constant [a]).
  toListOf = optic: optic (_P: (x: [ x ])) (profunctors.Forget monoids.list);

  # foldMapOf :: Monoid m => (forall p. Traversing p => Optic p s t a b) -> Dict m -> (a -> m) -> s -> m
  foldMapOf =
    optic: monoid: f:
    optic (_P: f) (profunctors.Forget monoid);

  # view :: (forall p. Traversing p => Optic p s t a b) -> s -> a?
  # Note: This is not the usual definition of 'view' which only works for Lens.
  #       Here it uses Traversal which works for all optics in this library, and is called 'preview' elsewhere.
  view = optic: foldMapOf optic monoids.first (x: x);

  # match :: Prism s t a b -> s -> Either a t
  #       :: (forall p. Choice p => (Dict p -> p a b) -> (Dict p -> p s t)) -> s -> Either a t
  # Here we instantiate 'p' with Star Either.
  match = optic: optic (_P: x: { left = x; }) (profunctors.Star functors.Either);

  # build :: Prism s t a b -> b -> t
  #       :: (forall p. Choice p => (Dict p -> p a b) -> (Dict p -> p s t)) -> b -> t
  build =
    optic: x:
    let
      # Tagged b c = Tagged { runTagged :: c }
      # Here we instantiate 'p' with Tagged.
      Tagged = {
        dimap =
          f: g: x:
          g x;
        left = x: { left = x; };
      };
    in
    optic (_P: x) Tagged;

  # preview :: Affine s t a b -> s -> Either a t
  # Affine's preview is just match.
  preview = match;

  anyOf = optic: foldMapOf optic monoids.any (x: x);
  allOf = optic: foldMapOf optic monoids.all (x: x);
  sumOf = optic: foldMapOf optic monoids.sum (x: x);
  productOf = optic: foldMapOf optic monoids.product (x: x);
  lengthOf = optic: foldMapOf optic monoids.sum (_: 1);

  inherit (optics)
    lens
    prism
    affine
    each
    compose
    attr
    attr'
    at
    ix
    _Just
    filtered
    iso
    json
    non
    path
    ;
}

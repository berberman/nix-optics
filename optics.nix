{ lib, classes }:
# Optics p s t a b = (Dict p -> p a b) -> (Dict p -> p s t)
let
  inherit (classes) profunctors;
in
rec {
  # Lens s t a b = forall p. Strong p => Optics p s t a b
  # lens :: (s -> a) -> (s -> b -> t) -> Lens s t a b
  #      :: (s -> a) -> (s -> b -> t) -> (forall p. Strong p => (Dict p -> p a b) -> (Dict p -> p s t))
  lens =
    # get :: s -> a
    # set :: s -> b -> t
    # l :: Dict p -> p a b
    get: set: l: P:
    # p (a, s) (b, s) -> p s t
    P.dimap
      # s -> (a, s)
      (s: {
        fst = get s;
        snd = s;
      })
      # (b, s) -> t
      (r: set r.snd r.fst)
      # p a b -> p (a, s) (b, s)
      (P.first (l P));

  # Prism s t a b = forall p. Choice p => Optics p s t a b
  # prism :: (s -> Either a t) -> (b -> t) -> Prism s t a b
  prism =
    # match :: s -> Either a t
    # build :: b -> t
    # pr :: Dict p -> p a b
    match: build: pr: P:
    # p (Either a t) (Either b t) -> p s t
    P.dimap
      # s -> Either a t
      match
      # Either b t -> t
      (r: if r ? left then build r.left else r.right)
      # p a b -> p (Either a t) (Either b t)
      (P.left (pr P));

  # Affine s t a b = forall p. (Strong p, Choice p) => Optics p s t a b
  # affine :: (s -> Either a t) -> (s -> b -> t) -> Affine s t a b
  affine =
    # preview :: s -> Either a t
    # set :: s -> b -> t
    # af :: Dict p -> p a b
    preview: set: af: P:
    P.dimap
      # s -> Either (a, s) t
      (
        s:
        let
          # e :: Either a t
          e = preview s;
        in
        if e ? left then
          # Left (a, s)
          {
            left = {
              fst = e.left;
              snd = s;
            };
          }
        else
          # Right t
          { right = e.right; }
      )
      # Either t t -> t
      (r: if r ? left then r.left else r.right)
      (
        # p (a, s) t -> p (Either (a, s) t) (Either t t)
        P.left (
          # p (a, s) (b, s) -> p (a, s) t
          P.dimap (x: x) (r: set r.snd r.fst)
            # p a b -> p (a, s) (b, s)
            (P.first (af P))
        )
      );

  # Iso s t a b = forall p. Profunctor p => Optics p s t a b
  # iso :: (s -> a) -> (b -> t) -> Iso s t
  iso =
    to: from: l: P:
    P.dimap to from (l P);

  # each :: forall p. Traversing p => Optic p (c a) (c b) a b, where c is either List or AttrSet
  each = tr: P: P.traverse (tr P);

  # Function composition
  # compose [f g h ...] = f . g . h . ... = f (g (h (...)))
  # Don't confuse with the order :)
  compose = lib.foldr (
    l: acc: x:
    l (acc x)
  ) (x: x);

  # attr :: String -> Lens AttrSet AttrSet a b
  attr = key: lens (s: s.${key}) (s: v: s // { ${key} = v; });

  # attr' :: String -> Affine AttrSet AttrSet a b
  # Safe attribute access (Affine: 0 or 1 target)
  # Note: Unlike 'attr' or 'at', if 'key' is missing, set leaves the AttrSet unchanged.
  attr' =
    key:
    affine (s: if s ? ${key} then { left = s.${key}; } else { right = s; }) (
      s: v: s // { ${key} = v; }
    );

  # at :: String -> Lens AttrSet AttrSet a? b?
  # Set to null to remove the attribute.
  at =
    key:
    lens (s: if s ? ${key} then s.${key} else null) (
      s: v: if v == null then builtins.removeAttrs s [ key ] else s // { ${key} = v; }
    );

  # ix :: Int -> Affine [a] [b] a b
  ix =
    index:
    with builtins;
    affine
      # preview: get element at index if in bounds
      (
        list: if index >= 0 && index < length list then { left = elemAt list index; } else { right = list; }
      )
      # set: insert element at index
      (list: v: lib.updateAt index v list);

  # _Just :: Prism a? b? a b
  _Just = prism (s: if s != null then { left = s; } else { right = null; }) (b: b);

  # filtered :: (s -> Bool) -> Prism s s s s
  filtered = predicate: prism (s: if predicate s then { left = s; } else { right = s; }) (b: b);

  # json :: Iso String String a a
  json = iso builtins.fromJSON builtins.toJSON;

  # non :: a -> Iso (a?) (a?) a a
  non = def: iso (x: if x == null then def else x) (y: if y == def then null else y);

  # path :: [String] -> Lens AttrSet AttrSet a b
  path = keys: compose (builtins.map attr keys);
}

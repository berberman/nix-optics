{ lib }:
rec {

  # ---------------------------
  # Monoids
  # ---------------------------
  monoids = {
    sum = {
      empty = 0;
      combine = x: y: x + y;
    };
    product = {
      empty = 1;
      combine = x: y: x * y;
    };
    list = {
      empty = [ ];
      combine = x: y: x ++ y;
    };
    any = {
      empty = false;
      combine = x: y: x || y;
    };
    all = {
      empty = true;
      combine = x: y: x && y;
    };
    first = {
      empty = null;
      combine = x: y: if x != null then x else y;
    };
  };

  # ---------------------------
  # Applicative Functors
  # ---------------------------
  # We assume that the data passed in is unwrapped.
  # Each instance must implement:
  #  fmap :: (a -> b) -> f a -> f b
  #  pure :: a -> f a
  #  liftA2 :: (a -> b -> c) -> f a -> f b -> f c
  functors = {
    # Identity a = Identity { runIdentity :: a }
    # We make it transparent by just using the value directly.
    Identity = {
      fmap = f: x: f x;
      pure = x: x;
      liftA2 =
        f: x: y:
        f x y;
    };
    # Constant c a = Constant { getConstant :: c }
    # We ignore 'a' and just pass around 'c'.
    # 'c' needs to be a Monoid for Constant to be an Applicative Functor.
    Constant = monoid: {
      fmap = f: c: c;
      pure = x: monoid.empty;
      liftA2 =
        f: c1: c2:
        monoid.combine c1 c2;
    };
    # Either a b = Left a | Right b
    Either = {
      fmap = f: e: if e ? left then e else { right = f e.right; };
      pure = x: { right = x; };
      liftA2 =
        f: x: y:
        if x ? left then
          x
        else if y ? left then
          y
        else
          { right = f x.right y.right; };
    };
  };

  # ---------------------------
  # Profunctors
  # ---------------------------
  # Combining Profunctor, Strong, Choice, and Traversing
  # Unused methods are omitted for brevity, and traversing only works for lists here.
  # Each instance must implement:
  #   dimap :: (a -> b) -> (c -> d) -> p b c -> p a d
  #   first :: p a b -> p (a, c) (b, c)
  #   left :: p a b -> p (Either a c) (Either b c)
  #   traverse :: p a b -> p (c a) (c b), where c is either List or AttrSet
  profunctors = rec {
    # Star f d c = Star { runStar :: d -> f c }
    # F is an Applicative Functor dictionary, providing fmap, pure, and liftA2.
    # Star lifts an applicative functor into a profunctor satisfying our constraints.
    Star = F: {
      # instance Profunctor (Star f)
      # dimap :: (a -> b) -> (c -> d) -> (b -> f c) -> (a -> f d)
      dimap =
        ab: cd: bfc: a:
        F.fmap cd (bfc (ab a));

      # instance Strong (Star f)
      # first :: (a -> f b) -> ((a, c) -> f (b, c))
      first =
        # input :: (a, c)
        afb: input:
        F.fmap (b: {
          fst = b;
          snd = input.snd;
        }) (afb input.fst);

      # instance Choice (Star f)
      # left :: (a -> f b) -> (Either a c -> f (Either b c))
      left =
        afb: input:
        if input ? left then
          F.fmap (b: { left = b; }) (afb input.left)
        else
          F.pure { right = input.right; };

      # instance Traversing (Star f)
      # traverse :: (a -> f b) -> [a] -> f [b]
      # traverse :: (a -> f b) -> AttrSet -> f AttrSet
      # TODO: Performance? Now unused and being overridden in specific instances.
      traverse =
        afb: list:
        if builtins.isAttrs list then
          lib.foldr (k: acc: F.liftA2 (b: bs: bs // { ${k} = b; }) (afb list.${k}) acc) (F.pure { }) (
            builtins.attrNames list
          )
        else
          lib.foldr (a: acc: F.liftA2 (b: bs: [ b ] ++ bs) (afb a) acc) (F.pure [ ]) list;
    };

    # The function arrow (->), or:
    # Arrow a b = Arrow { runArrow :: a -> b }
    Arrow = Star functors.Identity // {
      # Specialized for Identity
      # traverse :: (a -> b) -> [a] -> [b]
      # traverse :: (a -> b) -> AttrSet -> AttrSet
      traverse = h: s: if builtins.isAttrs s then builtins.mapAttrs (_: v: h v) s else map h s;
    };

    # Forget r a b = Forget { runForget :: a -> r }
    # 'Forget r' is isomorphic to 'Constant r a' lifted to a profunctor.
    # It requires a monoid to combine results when traversing.
    Forget =
      monoid:
      Star (functors.Constant monoid)
      // {
        # Specialized for Constant (thanks to the associativity)
        # traverse :: Monoid r => (a -> r) -> [a] -> r
        # traverse :: Monoid r => (a -> r) -> AttrSet -> r
        traverse =
          h: s:
          if builtins.isAttrs s then
            builtins.foldl' monoid.combine monoid.empty (map h (builtins.attrValues s))
          else
            builtins.foldl' monoid.combine monoid.empty (map h s);
      };
  };

}

# nix-optics

Naive implementation of Profunctor Optics in Nix.

Some good resources to understand optics:
- [Don't Fear The Profunctor Optics](https://github.com/hablapps/DontFearTheProfunctorOptics)
- [Profunctor Optics: Modular Data Accessors](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/poptics.pdf)

The foundation of this library is almost entirely based on the above two resources, with some inspiration from Haskell's [lens](https://hackage.haskell.org/package/lens) and [microlens](https://hackage-content.haskell.org/package/microlens) libraries.

## Structure

- `default.nix`: Entry point that exposes the optics library. Also includes accessories like `view`, `over`, `set`, etc.
- `classes.nix`: Class dictionaries for Profunctors, Strong, Choice, etc.
- `optics.nix`: Implementation of Lenses, Prisms, Affines, Isos, and Traversals. Also includes common optics like `_Just`, `ix`, `at`, etc.
- `example.nix`: Some LLM-generated examples :(

These files are well-documented, so please refer to the comments in the code for type signatures and details.

## Example

```nix
{ nix-optics, ... }:
let
  inherit (nix-optics.lib)
    view
    set
    over
    toListOf
    attr
    ix
    each
    compose
    _Just
    non
    json
    filtered
    ;

  # A complex nested data structure
  data = {
    users = [
      {
        id = 1;
        name = "Alice";
        preferences = {
          theme = "dark";
          notifications = true;
        };
        # Metadata stored as a JSON string
        meta = "{\"login_count\": 42}";
      }
      {
        id = 2;
        name = "Bob";
        preferences = null; # Missing
        meta = "{\"login_count\": 0}";
      }
    ];
  };

  # Optics
  users = attr "users";
  metadata = compose [
    (attr "meta")
    json # Automatically converts between JSON and AttrSet
  ];
  loginCount = compose [
    metadata
    (attr "login_count")
  ];
  preferences = compose [
    (attr "preferences")
    _Just # Ignore if null
  ];

in
{

  # Get Alice's theme
  aliceTheme = view (compose [
    users
    (ix 0)
    preferences
    (attr "theme")
  ]) data;
  # => "dark"

  # Increment login count for every user
  updatedLogins = over (compose [
    users
    each
    loginCount
  ]) (n: n + 1) data;
  # => Alice's meta becomes "{\"login_count\": 43}"

  # Set Bob's theme to "light", initializing preferences if missing
  fixBob = set (compose [
    users
    (ix 1)
    (attr "preferences")
    (non { }) # Replaces null with empty set before we write to it
    (attr "theme")
  ]) "light" data;
  # => Bob.preferences becomes { theme = "light"; }

  # Get a list of all user names
  allNames = toListOf (compose [
    users
    each
    (attr "name")
  ]) data;
  # => [ "Alice" "Bob" ]

  # Get names of users who have logged in at least once
  activeUsers = toListOf (compose [
    users
    each
    (filtered (u: (view loginCount u) > 0))
    (attr "name")
  ]) data;
  # => [ "Alice" ]
}


```

## Documentation

Types of Optics:

```haskell
Optics p s t a b = p a b -> p s t
Lens s t a b = forall p. Strong p => Optics p s t a b
Prism s t a b = forall p. Choice p => Optics p s t a b
Affine s t a b = forall p. (Strong p, Choice p) => Optics p s t a b
Iso s t a b = forall p. Profunctor p => Optics p s t a b
Traversal s t a b = forall p. Traversing p => Optics p s t a b
```

The type constraints on `p` indicate the capabilities required from the profunctor to construct that optic. The hierarchy of optics is as follows:

```
Iso (Profunctor)                    
      │                             
      │                             
      ├─────   Lens (Strong)   ───┐ 
      │                           │ 
      │                           │ 
      └─────   Prism (Choice)  ───┤ 
                                  │ 
                       ┌──────────┘           
            Affine (Strong + Choice)
                       │                  
                   Traversal        
```

It flows from the most capable `Iso` to least capable `Traversal`. Each optic can be used wherever a less capable optic is required. The resulting optic of composing two optics takes the intersection of their capabilities. For example:

- `Lens` + `Prism` = `Affine`
- `Lens` + `Iso` = `Lens`
- `Prism` + `Affine` = `Prism`
- `Traversal` + `Lens` = `Traversal`

### Operators

Let's roughly denote an Optic as `Optic s t a b` in this section for simplicity. The compatible optics for each operator are mentioned, and we'll see different constructions in the next section.

- `view :: Optic s t a b -> s -> a?`: Extracts the first focus of the optic from the structure `s`. Returns `null` if the focus is not present. Works with all optics.

  ```nix
  view (attr "x") { x = 10; y = 20; }
  # => 10
  ```

- `over :: Optic s t a b -> (a -> b) -> s -> t`: Modifies the focus of the optic using a function. Works with all optics.

  ```nix
  over (attr "count") (x: x + 1) { count =  0; }
  # => { count = 1; }
  ```

- `set :: Optic s t a b -> b -> s -> t`: Replaces the focus of the optic with a new value. Works with all optics.

  ```nix
  set (attr "valid") true { valid = false; }
  # => { valid = true; }
  ```

- `toListOf :: Optic s t a b -> s -> [a]`: Extracts all targets of an optic into a list. Useful with `each`. Works with all optics.

  ```nix
  toListOf each { a = 1; b = 2; }
  # => [ 1 2 ]

  toListOf (compose [ each (attr "x") ]) [ { x = 1; } { x = 2; } ]
  # => [ 1 2 ]
  ```

- `match/preview :: Optic s t a b -> s -> Either a t`: Attempts to match a `Prism` or `Affine`. Returns `{ left = value; }` on success or `{ right = newStructure; }` on failure. Works with `Prism` and `Affine` optics. (It won't fail on others but not very useful.)

  ```nix
  match _Just 5
  # => { left = 5; }

  match _Just null
  # => { right = null; }
  ```

- `build`: Constructs a structure from a value. Works with `Iso` and `Prism` optics. Not very useful so far.

  ```nix
  build _Just 10
  # => 10

  build json { a = 1; }
  # => "{ \"a\": 1 }"
  ```

  > Note: `build (compose [ _Just (attr "x") ]) 10` would fail because the resulting optic is an `Affine`, not a `Prism`.

- Folds (`sumOf`, `productOf`, `anyOf`, `allOf`, `lengthOf`): Aggregate values focused. Works with `Traversals` (`each`).
  ```nix
  anyOf each [ false true ]
  # => true

  sumOf (compose [ each (attr "x") ]) [ { x = 1; } { x = 2; } { x = 3; } ]
  # => 6
  ```

### Optic Constructors

- `lens :: (s -> a) -> (s -> b -> t) -> Lens s t a b`: Constructs a Lens from a getter and a setter.
  ```nix
  let first = lens (p : p.fst) (p: v: p // { fst = v; }); 
      pair = { fst = 1; snd = 2; };
  in
    view first pair
    # => 1
  
    set first 10 pair
    # => { fst = 10; snd = 2; }
  ```

- `prism :: (s -> Either a t) -> (b -> t) -> Prism s t a b`: Constructs a Prism from a matcher and a builder. See `_Just` for an example.

- `affine :: (s -> Either a t) -> (s -> b -> t) -> Affine s t a b`: Constructs an Affine from a matcher and a setter. See `ix` for an example.

- `iso :: (s -> a) -> (b -> t) -> Iso s t a b`: Constructs an Iso from a pair of functions. See `json` for an example.

### Some Common Optics

- `compose :: [Optic] -> Optic`: Optics can be composed as functions naturally.
  ```nix
  view (compose [ (attr "a") (attr "b") ]) { a = { b = 99; }; }
  ```
- `attr :: String -> Lens AttrSet AttrSet a b`: Lens focusing on an attribute of an attribute set. Fails if the attribute does not exist.
  ```
  set (attr "foo) 42 { foo = 0; bar = 1; }
  # => { foo = 42; bar = 1; }
  ```
- `attr' :: String -> Affine AttrSet AttrSet a b`: Affine focusing on an attribute of an attribute set. Does nothing if the attribute does not exist. Note: it never creates new attributes.
  ```nix
  set (attr' "a") 2 { a = 1; }
  # => { a = 2; }

  set (attr' "b") 2 { a = 1; }
  # => { a = 1; }
  ```
- `at :: String -> Lens AttrSet AttrSet a? b?`: Lens focusing on a nullable attribute. Allows deleting by setting it to `null`.
  ```nix
  set (at "a") null { a = 1; b = 2; }
  # => { b = 2; }

  set (at "c") 3 { a = 1; b = 2; }
  # => { a = 1; b = 2; c = 3; }
  ```

- `ix :: Int -> Affine [a] [b] a b`: Affine focusing on a specific index of a List. Does nothing if the index is out of bounds.
  ```nix
  set (ix 1) 233 [ 1 2 3 ]
  # => [ 1 233 3 ]

  set (ix 233) 99 [ 1 2 3 ]
  # => [ 1 2 3 ]
  ```
- `each :: Traversal (c a) (c b) a b` where `c` is either List or AttrSet: Traversal over all elements of a List or AttrSet.
  ```nix
  over each (x: x * 2) [ 1 2 3 ]
  # => [ 2 4 6 ]

  over each (x: x + 1) { a = 1; b = 2; }
  # => { a = 2; b = 3; }
  ```

- `filtered :: (a -> Bool) -> Prism a a a a`: Prism focusing on values that satisfy a predicate.
  ```nix
  view (filtered (x: x > 0)) 10
  # => 10

  # Increment only even numbers
  over (compose [ each (filtered (x: x / 2 * 2 == x)) ]) (x: x + 1) [ 1 2 3 4 ]
  # => [ 1 3 3 5 ]
  ```

- `_Just :: Prism a? b? a b`: Prism focusing on the value if it's not null.
  ```nix
  toListOf (compose [ each _Just ]) [ 1 null 2 null 3 ]
  # => [ 1 2 3 ]
  ```

- `non :: a -> Iso a? a? a a`: An Iso that substitutes `null` with a default value.
  ```nix
  toListOf (compose [ each (non 0) ]) [ 1 null 2 null 3 ]
  # => [ 1 0 2 0 3 ]

  view (compose [ (at "missing") (non 0) ]) { }
  # => 0
  ```

- `json :: Iso String String a a`: An Iso that converts between JSON strings and Nix values.
  ```nix
  view json "{\"a\": 1}"
  # => { a = 1; }

  over json (x: x // { a = 1; }) "{\"b\": 2}"
  "{\"a\":1,\"b\":2}"
  ```

## TODO

- Properly implement Traversals: now they are specialized to Lists only and very ad-hoc, though I'm not sure if it's a good idea to introduce a separate `Monoidal` class, or even representable functors...
- Add more useful optics and combinators for common use cases in Nix.
- Write tests and examples.

## Contributing

Issues and PRs are always welcome. **\_(:з」∠)\_**

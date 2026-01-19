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
    sumOf
    compose
    over
    attr
    each
    _Just
    non
    ;
  data = {
    users = [
      {
        name = "Alice";
        score = 10;
      }
      {
        name = "Bob";
        score = 20;
      }
      {
        name = "Carol";
        score = null;
      }
    ];
  };
  totalScore = sumOf (compose [
    (attr "users")
    each
    (attr "score")
    (non 2333) # Default score if null
  ]) data;
  updatedData = over (compose [
    (attr "users")
    each
    (attr "score")
    _Just # Ignore null scores
  ]) (score: score + 5) data;
in
{
  inherit totalScore updatedData;
}

```

## TODO

- Properly implement Traversals: now they are specialized to Lists only and very ad-hoc, though I'm not sure if it's a good idea to introduce a separate `Monoidal` class, or even representable functors...
- Add more useful optics and combinators for common use cases in Nix.
- Write tests and examples.

## Contributing

Issues and PRs are always welcome. **\_(:з」∠)\_**

let
  L = import ./default.nix;
  inherit (L)
    compose

    # Optics
    attr # Focus on a required key
    attr_ # Focus on a key safely (ignores if missing)
    at # Focus on a nullable key (allows insert/delete)
    ix # Focus on a list index
    each # Focus on every item in a List
    filtered # Focus if predicate matches
    _Just # Focus if not null

    # Isomorphisms
    json # Treat string as JSON data
    non # Provide default value if null

    # Verbs
    view
    set
    over
    toListOf
    sumOf
    ;
  # ==========================================================

  cloudConfig = {
    region = "us-east-1";
    deploy = {
      blue = {
        active = true;
        replicas = 3;
        version = "v1.0";
      };
      green = {
        active = false;
        replicas = 0;
        version = "v1.1";
      };
    };
    # JSON string
    meta = ''{"created_by": "terraform", "retention_days": 30}'';
  };

  serverMetrics = [
    {
      id = "srv-1";
      cpu = 45;
      mem = 80;
      tags = [
        "web"
        "prod"
      ];
    }
    {
      id = "srv-2";
      cpu = 12;
      mem = 30;
      tags = [
        "db"
        "prod"
      ];
    }
    {
      id = "srv-3";
      cpu = 99;
      mem = 90;
      tags = [
        "web"
        "dev"
      ];
    }
    {
      id = "srv-4";
      cpu = null;
      mem = null;
      tags = [ "spare" ];
    }
  ];
  # ==========================================================
  # Example 1: Update green to active
  example1 = set (compose [
    (attr "deploy")
    (attr "green")
    (attr "active")
  ]) true cloudConfig;
  # ==========================================================
  # Example 2: Find all 'web' servers that are overloading (cpu > 80)
  # and tag them as "critical".
  example2 = over (compose [
    each
    (filtered (s: s.cpu != null && s.cpu > 80))
    (filtered (s: builtins.elem "web" s.tags))
    (attr "tags")
  ]) (tags: tags ++ [ "critical" ]) serverMetrics;
  # ==========================================================
  # Example 3: Edit JSON metadata to add 60 days retention
  example3 = over (compose [
    (attr "meta")
    json
    (attr "retention_days")
  ]) (x: x + 60) cloudConfig;
  # ==========================================================
  # README
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
assert example1.deploy.green.active == true;
assert builtins.elem "critical" ((builtins.elemAt example2 2).tags);
assert
  builtins.fromJSON example3.meta == {
    created_by = "terraform";
    retention_days = 90;
  };
{
  inherit updatedData;
}

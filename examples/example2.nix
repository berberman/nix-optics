let
  optics = import ../default.nix;
  inherit (optics)
    view
    set
    over
    toListOf
    match
    build
    attr
    attr'
    at
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
        preferences = null; # Missing structure
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

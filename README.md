# `persistent-records` Generate record types and mappers from Persistent entities 

Work in progress


Example usage:

**Before (manual):**
```haskell
share [mkPersist sqlSettings{mpsPrefixFields = False}] [persistLowerCase|
  User sql=users
    name Text
    email Text
    blocked Bool
|]

data UserView = MkUserView
  { id :: !Int64
  , name :: !Text
  , email :: !Text
  , blocked :: !Bool
  }
  deriving (Eq, Show, Generic)

entityToUserView :: Entity User -> UserView
entityToUserView (Entity k v) = MkUserView
  { id = fromSqlKey k
  , name = v.name
  , email = v.email
  , blocked = v.blocked
  }
```

**After (with persistent-records):**
```haskell
share [mkPersist sqlSettings{mpsPrefixFields = False}] [persistLowerCase|
  User sql=users
    name Text
    email Text
    blocked Bool
|]

genRec ''User
-- Generates UserView and entityToUserView automatically
```
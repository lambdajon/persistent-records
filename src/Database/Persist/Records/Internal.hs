{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TemplateHaskell #-}

{- |
Internal helper functions used by the Template Haskell implementation.
These are not part of the public API and may change without notice.
-}
module Database.Persist.Records.Internal
  ( -- * Field extraction
    extractFields
  , extractTyVars

    -- * Field filtering
  , filterFields

    -- * Name generation
  , mkTypeName
  , mkConName
  , mkMapperName

    -- * Field name utilities
  , stripEntityPrefix
  , toRecordFieldName

    -- * Key type extraction
  , extractKeyInfo
  , KeyInfo (..)

    -- * Type utilities
  , isMaybeType
  , wrapMaybe
  ) where

import Data.Char (toLower)
import Data.Int (Int64)
import Database.Persist.Records.Config (RecConfig (..))
import Language.Haskell.TH

-- | Extract record fields from a type's Info.
extractFields :: Info -> Q [(Name, Type)]
extractFields = \case
  TyConI (DataD _ _ _ _ [RecC _ vbts] _) ->
    pure [(name, typ) | (name, _, typ) <- vbts]
  TyConI (NewtypeD _ _ _ _ (RecC _ vbts) _) ->
    pure [(name, typ) | (name, _, typ) <- vbts]
  TyConI (DataD _ name _ _ _ _) ->
    fail $ "Expected a single record constructor for " <> nameBase name
  TyConI (NewtypeD _ name _ _ _ _) ->
    fail $ "Expected a record constructor for newtype " <> nameBase name
  _ ->
    fail "Expected a data or newtype declaration"

-- | Extract type variables
extractTyVars :: Info -> Q [TyVarBndr BndrVis]
extractTyVars = \case
  TyConI (DataD _ _ tvs _ _ _) -> pure tvs
  TyConI (NewtypeD _ _ tvs _ _ _) -> pure tvs
  _ -> fail "Expected a data or newtype declaration"

-- | Filter fields based on configuration.
filterFields :: RecConfig -> Name -> [(Name, Type)] -> [(Name, Type)]
filterFields config entityName fields
  | not (null config.recOnlyFields) =
      filter (\(n, _) -> stripEntityPrefix entityName n `elem` config.recOnlyFields) fields
  | not (null config.recSkipFields) =
      filter (\(n, _) -> stripEntityPrefix entityName n `notElem` config.recSkipFields) fields
  | otherwise = fields

{- | Generate the type name for the generated record.
Combines prefix + original name + suffix.
-}
mkTypeName :: RecConfig -> Name -> Name
mkTypeName config originalName =
  mkName $ config.recPrefix <> nameBase originalName <> config.recSuffix

{- | Generate the constructor name for the generated record.
Combines constructor prefix + prefix + original name + suffix.
-}
mkConName :: RecConfig -> Name -> Name
mkConName config originalName =
  mkName
    $ config.recConPrefix
      <> config.recPrefix
      <> nameBase originalName
      <> config.recSuffix

{- | Generate the mapper function name.
Combines mapper prefix + prefix + original name + suffix.
-}
mkMapperName :: RecConfig -> Name -> Name
mkMapperName config originalName =
  mkName
    $ config.recMapperPrefix
      <> config.recPrefix
      <> nameBase originalName
      <> config.recSuffix

-- | Strip the entity name prefix from a field name.
stripEntityPrefix :: Name -> Name -> String
stripEntityPrefix eName fName =
  let e = nameBase eName
      f = nameBase fName
      entityLower = map toLower e
   in if take (length e) f == entityLower then case drop (length e) f of
        (c : cs) -> toLower c : cs
        [] -> f
      else
        f

-- | Convert a field name to the record field name by stripping the entity prefix.
toRecordFieldName :: Name -> Name -> Name
toRecordFieldName eName fName =
  mkName $ stripEntityPrefix eName fName

-- | entity's key type.
data KeyInfo = KeyInfo
  { keyIdType :: Type
  , keyAccessor :: Name
  }

{- | Extract key type information from a Persistent entity.

For default keys (Int64-backed), returns Int64 with fromSqlKey.
For custom keys (e.g., UUID), returns the custom type with the generated accessor.
-}
extractKeyInfo :: Name -> Q KeyInfo
extractKeyInfo entityName = do
  -- Try to look up the key accessor function (e.g., unReporterKey)
  let accessorStr = "un" <> nameBase entityName <> "Key"

  mbAccessor <- lookupValueName accessorStr

  case mbAccessor of
    Just accName -> do
      accessorInfo <- reify accName
      case accessorInfo of
        VarI _ accessorType _ -> do
          -- The accessor type is like: Key Reporter -> UUID
          case extractResultType accessorType of
            Just idType
              -- If the result type is BackendKey, use default Int64 handling
              | isBackendKeyType idType -> defaultKeyInfo
              | otherwise -> pure $ KeyInfo idType accName
            Nothing -> defaultKeyInfo
        _ -> defaultKeyInfo
    Nothing -> defaultKeyInfo
 where
  -- For default keys, use Int64 and fromSqlKey from Database.Persist.Sql
  defaultKeyInfo = pure $ KeyInfo (ConT ''Int64) (mkName "fromSqlKey")

  extractResultType :: Type -> Maybe Type
  extractResultType (ForallT _ _ t) = extractResultType t
  extractResultType (AppT (AppT ArrowT _) resultType) = Just resultType
  extractResultType _ = Nothing

  -- Check if a type is BackendKey (default Int64)
  isBackendKeyType :: Type -> Bool
  isBackendKeyType (AppT (ConT n) _) = nameBase n == "BackendKey"
  isBackendKeyType (ConT n) = nameBase n == "BackendKey"
  isBackendKeyType _ = False

isMaybeType :: Type -> Bool
isMaybeType (AppT (ConT m) _) = m == ''Maybe
isMaybeType _ = False

-- | Wrap type Maybe
wrapMaybe :: Type -> Type
wrapMaybe typ
  | isMaybeType typ = typ
  | otherwise = AppT (ConT ''Maybe) typ

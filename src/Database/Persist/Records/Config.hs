{-# LANGUAGE DuplicateRecordFields #-}

{- |
Module      : Database.Persist.Records.Config
Description : Configuration for record generation

Configuration types for controlling how records are generated from
Persistent entities.
-}
module Database.Persist.Records.Config
  ( RecConfig (..)
  , defaultConfig
  ) where

import Data.Default (Default (..))
import Language.Haskell.TH (Name)

-- | Configuration for record generation.
data RecConfig = RecConfig
  { recPrefix :: String
  {- ^ Prefix for type name default: ""
  Example: \"Update\" → @UpdateUser@
  -}
  , recSuffix :: String
  {- ^ Suffix for type name default: \"View"\
  Example: \"View"\ → @UserView@
  -}
  , recConPrefix :: String
  {- ^ Constructor prefix: \"Mk"\
  Example: \"Mk\" → @MkUserView@
  -}
  , recSkipFields :: [String]
  {- ^ Exclude fields.
  Example: ["password", "salt"]
  -}
  , recOnlyFields :: [String]
  {- ^ Include fields
  Example: ["name", "email"]
  -}
  , recAddId :: Bool
  -- ^ Add id as first field. Default: True
  , recIdType :: Maybe Name
  {- ^ Type for the id field. Default: Nothing (Int64)
  Example: Just ''UUID for UUID primary keys
  -}
  , recIdConvert :: Maybe Name
  {- ^ Function to convert Key to id type. Default: Nothing (fromSqlKey)
  Example: Just 'unUserKey for custom key extraction
  -}
  , recWrapMaybe :: Bool
  {- ^ Wrap all field types in Maybe. Default: False
  Useful for PATCH/partial update records.
  -}
  , recStrictFields :: Bool
  -- ^ Use strict fields . Default: True
  , recMapperPrefix :: String
  -- ^ Mapper function prefix default: "entityTo" Example: "entityTo" → @entityToUserView@
  , recGenerateMapper :: Bool
  -- ^ Generate mapper function deefault: Tue
  }

defaultConfig :: RecConfig
defaultConfig =
  RecConfig
    { recPrefix = ""
    , recSuffix = "View"
    , recConPrefix = "Mk"
    , recSkipFields = []
    , recOnlyFields = []
    , recAddId = True
    , recIdType = Nothing
    , recIdConvert = Nothing
    , recWrapMaybe = False
    , recStrictFields = True
    , recMapperPrefix = "entityTo"
    , recGenerateMapper = True
    }

instance Default RecConfig where
  def = defaultConfig

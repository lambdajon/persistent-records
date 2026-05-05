{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TemplateHaskell #-}

{- |
Module      : Database.Persist.Records.TH
Template Haskell functions for generating record types and mappers
from Persistent entities.
-}
module Database.Persist.Records.TH
  ( genRec
  , genRecWith
  ) where

import Database.Persist (Entity (..))
import Database.Persist.Records.Config (RecConfig (..), defaultConfig)
import Database.Persist.Records.Internal
import Language.Haskell.TH

{- | Generate a record type and mapper using default configuration.

This generates a record with:

* Type name: @OriginalNameView@
* Constructor: @MkOriginalNameView@
* An @id :: !Int64@ field as the first field
* All fields from the original record (strict)
* A mapper function @entityToOriginalNameView :: Entity OriginalName -> OriginalNameView@
-}
genRec :: Name -> Q [Dec]
genRec = genRecWith defaultConfig

{- | Generate a record type and mapper with custom configuration.

See 'RecConfig' for available options.
-}
genRecWith :: RecConfig -> Name -> Q [Dec]
genRecWith config entityName = do
  info <- reify entityName
  fields <- extractFields info
  tyVars <- extractTyVars info
  keyInfo <- extractKeyInfo entityName

  let filteredFields = filterFields config entityName fields
      typeName = mkTypeName config entityName -- 5. Build the new record type name
      conName = mkConName config entityName

  recFields <- buildFields config keyInfo entityName filteredFields

  let dataDec = mkDataDec typeName tyVars conName recFields

  mapperDecs <-
    if config.recGenerateMapper then
      mkMapper config keyInfo entityName typeName tyVars conName filteredFields
    else
      pure []

  pure $ dataDec : mapperDecs

-- | Build the list of record fields for the generated type.
buildFields :: RecConfig -> KeyInfo -> Name -> [(Name, Type)] -> Q [VarBangType]
buildFields config keyInfo entityName fields = do
  let fieldBang =
        if config.recStrictFields then
          Bang NoSourceUnpackedness SourceStrict
        else
          Bang NoSourceUnpackedness NoSourceStrictness

      processType typ =
        if config.recWrapMaybe then
          wrapMaybe typ
        else
          typ

      idType = case config.recIdType of
        Just t -> ConT t
        Nothing -> keyInfo.keyIdType

      idField = (mkName "id", fieldBang, idType)

      regularFields =
        [ (toRecordFieldName entityName n, fieldBang, processType t)
        | (n, t) <- fields
        ]

  pure
    $ if config.recAddId then
      idField : regularFields
    else
      regularFields

{- | Generate the data declaration for the record.
Note: No deriving clauses are generated. Users should derive instances manually
using StandaloneDeriving or deriving strategies as needed.
-}
mkDataDec :: Name -> [TyVarBndr BndrVis] -> Name -> [VarBangType] -> Dec
mkDataDec typeName tyVars conName fields =
  let con = RecC conName fields in DataD [] typeName tyVars Nothing [con] []

-- | Generate the mapper function from Entity to the generated record.
mkMapper
  :: RecConfig
  -> KeyInfo
  -> Name
  -> Name
  -> [TyVarBndr BndrVis]
  -> Name
  -> [(Name, Type)]
  -> Q [Dec]
mkMapper config keyInfo originalName typeName tyVars conName fields = do
  keyVar <- newName "k"
  valVar <- newName "v"

  let mapperName = mkMapperName config originalName

  -- Use custom ID conversion function if specified, otherwise use auto-detected accessor
  let idConvertFn = case config.recIdConvert of
        Just f -> VarE f
        Nothing -> VarE keyInfo.keyAccessor

  -- Build field expressions
  -- The field name in the record uses stripped names (e.g., "name")
  -- but we access from the Persistent entity using original names (e.g., "userName")
  let idFieldExp = (mkName "id", AppE idConvertFn (VarE keyVar))
      fieldExps = [(toRecordFieldName originalName n, fieldAccess valVar n) | (n, _) <- fields]
      allFields =
        if config.recAddId then
          idFieldExp : fieldExps
        else
          fieldExps

  -- Record construction: MkFooView { id = fromSqlKey k, name = v.name, ... }
  let body = RecConE conName allFields

  -- Pattern: (Entity k v)
  let pat = ConP 'Entity [] [VarP keyVar, VarP valVar]

  -- Build the types with type variables applied
  let applyTyVars name = foldl AppT (ConT name) (map tyVarType tyVars)
      entityType = AppT (ConT ''Entity) (applyTyVars originalName)
      resultType = applyTyVars typeName

  -- Type signature
  let sig =
        if null tyVars then
          SigD mapperName (AppT (AppT ArrowT entityType) resultType)
        else
          SigD
            mapperName
            (ForallT (map toSpecifiedTyVarBndr tyVars) [] (AppT (AppT ArrowT entityType) resultType))

  -- Function
  let fun = FunD mapperName [Clause [pat] (NormalB body) []]

  pure [sig, fun]

{- | Generate a field access expression using OverloadedRecordDot syntax.
Generates: v.fieldName
-}
fieldAccess :: Name -> Name -> Exp
fieldAccess valVar fieldName = GetFieldE (VarE valVar) (nameBase fieldName)

-- | Extract the Type from a TyVarBndr.
tyVarType :: TyVarBndr BndrVis -> Type
tyVarType = \case
  PlainTV n _ -> VarT n
  KindedTV n _ k -> SigT (VarT n) k

-- | Convert a TyVarBndr BndrVis to TyVarBndr Specificity for ForallT.
toSpecifiedTyVarBndr :: TyVarBndr BndrVis -> TyVarBndr Specificity
toSpecifiedTyVarBndr = \case
  PlainTV n _ -> PlainTV n SpecifiedSpec
  KindedTV n _ k -> KindedTV n SpecifiedSpec k

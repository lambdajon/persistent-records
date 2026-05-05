{- |
Module      : Database.Persist.Records
Description : Generate record types and mappers from Persistent entities
Copyright   : (c) 2026, lambdajon
License     : BSD-3-Clause

This library provides Template Haskell functions to automatically generate
record types and mapper functions from Persistent entities.
-}
module Database.Persist.Records
  ( -- * Record Generation
    genRec
  , genRecWith

    -- * Configuration
  , RecConfig (..)
  , defaultConfig
  ) where

import Database.Persist.Records.Config (RecConfig (..), defaultConfig)
import Database.Persist.Records.TH (genRec, genRecWith)

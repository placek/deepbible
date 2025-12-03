module Domain.Note.Types where

type NoteId = Int

type Note =
  { id :: NoteId
  , content :: String
  }

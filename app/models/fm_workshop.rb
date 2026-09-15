# Workshop curriculum templates — art workshop lesson plans.
#
# FileMaker source: Workshops (Workshops.csv, 7,852 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   WorkshopID            PK
#   AuthorID              FK → FmRolodex
#   WorkshopTitle
#   SQLid
#   AboutWorkshop
#   AgeRange
#   ArtType
#   ProgramType
#   Setting
#   TimeFrame
#   Introduction
#   WarmUp
#   Opening
#   Materials
#   Preparation
#   Closing
#   Objective
#   FormatsStrengths
#   EmotionalTheme
#   HolidayTheme
#   CreationProcess
#   Description
#   Notes
#   Variations
#   Publication
#   PublicationDate
#   Ratio
#   TechInfo
#   AuthorFirstName
#   AuthorLastName
#   AuthorMiddleName
#   AuthorInfo
#   EnteredBy
#   ModifiedBy
#   DateEntered
#   DateModified
class FmWorkshop < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "WorkshopID"

  FM_LINKS = {
    "AuthorID" => "fm_rolodexes"
  }.freeze
end

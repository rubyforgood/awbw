# Quotations — participant quotes and testimonials.
#
# FileMaker source: Quotations (Quotations.csv, 141,474 rows).
# Fields below live in the `data` JSON column, except the primary key, which
# the import lifts into `fm_id`. FileMaker's zc*/zg*/zs* calc, global and
# summary fields are imported too but left out here — nothing reads them.
#
#   RecordID              PK
#   RolodexID             FK → FmRolodex (31 rows contain IDs from ~10 unknown
#                           tables: J, N, F, L, M, P, X, A, B, E, K, S, T prefixes)
#   EventID               FK → FmEvent
#   ProjectID             FK → FmProject (4 rows: newline-delimited ID list, free
#                           text project names, bare numeric without P prefix)
#   SourceID              FK → FmRolodex (9 rows are bare numeric, not Q-prefixed)
#   WorkshopID
#   Quotation
#   QuotationDate
#   PersonName
#   Age
#   Gender
#   Category
#   Code
#   Flags
#   Voice
#   WorkShopLeader
#   WorkshopName
#   EventName
#   ProjectName
#   ProjectType
#   SortOrder
#   EnteredBy
#   Notes
#   DateEntered
class FmQuotation < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "RecordID"

  FM_LINKS = {
    "RolodexID" => "fm_rolodexes",
    "EventID" => "fm_events",
    "ProjectID" => "fm_projects",
    "SourceID" => "fm_rolodexes"
  }.freeze
end

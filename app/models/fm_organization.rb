# frozen_string_literal: true

class FmOrganization < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "OrgID"

  FM_LINKS = {
    "ParentID" => "fm_organizations",
  }.freeze
end

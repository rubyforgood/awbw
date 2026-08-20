class FmPostalCode < ApplicationRecord
  include FmArchive
  FM_KEY_COLUMN = "Zipcode"

  FM_LINKS = {}.freeze
end

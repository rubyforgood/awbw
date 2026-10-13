class FmRolodexDecorator < ApplicationDecorator
  CONTACT_TAGS = {
    FmPhoneNumber => { "Primary" => "PrimaryPhoneID" },
    FmAddress => { "Primary" => "PrimaryAddrsID", "Worksite" => "WorksiteAddrsID" }
  }.freeze

  def contact_tags(record)
    CONTACT_TAGS.fetch(record.class).select { |_, key| data[key] == record.fm_id }.keys
  end
end

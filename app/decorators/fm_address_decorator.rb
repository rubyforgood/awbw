class FmAddressDecorator < ApplicationDecorator
  def kind
    data["AddrsType"].presence || "Address"
  end

  def summary
    state_and_zip = data.values_at("AddrsState", "AddrsPostalCode").compact_blank.join(" ")
    [ *data.values_at("AddrsLine1", "AddrsLine2", "AddrsCity"), state_and_zip, data["AddrsCountry"] ].compact_blank.join(", ")
  end
end

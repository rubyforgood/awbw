class FmAddressDecorator < ApplicationDecorator
  def kind
    data["AddrsType"].presence || "Address"
  end

  def summary
    state_and_zip = data.values_at("AddrsState", "AddrsPostalCode").compact_blank.join(" ")
    [ street, *data.values_at("AddrsLine2", "AddrsCity"), state_and_zip, data["AddrsCountry"] ].compact_blank.join(", ")
  end

  def street
    street_no = data["StreetNo"].to_s.strip
    line1 = data["AddrsLine1"].to_s.strip
    return line1 if street_no.empty? || line1.split.first == street_no

    [ street_no, line1 ].compact_blank.join(" ")
  end
end

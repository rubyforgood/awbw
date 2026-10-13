class FmPhoneNumberDecorator < ApplicationDecorator
  def kind
    data["PhoneType"].presence || "Phone"
  end

  def summary
    data.values_at("PhoneNumber", "Note").compact_blank.join(" · ")
  end
end

class FacilitatorDecorator < Draper::Decorator
  delegate_all

 DISPLAY_FIELDS = {
    "First name" => :first_name,
    "Last name" => :last_name,
    "Primary email address" => :primary_email_address,
    "Primary email type" => :primary_email_address_type,
    "Street address" => :street_address,
    "City" => :city,
    "State" => :state,
    "ZIP" => :zip,
    "Country" => :country,
    "Mailing address type" => :mailing_address_type,
    "Phone number" => :phone_number,
    "Phone number type" => :phone_number_type
  }

  def display_fields
    DISPLAY_FIELDS.map do |label, method|
      { label: label, value: object.send(method) }
    end
  end

  def pronouns_display
    profile_show_pronouns ? pronouns : nil
  end

  def member_since_year
    member_since ? member_since.year : nil
  end

  def badges
    years = member_since ? (Time.zone.now.year - member_since.year) : 0
    badges = []
    badges << ["Legacy Facilitator (10+ years)", "yellow"] if years >= 10
    badges << ["Seasoned Facilitator (3-10 years)", "gray"] if member_since.present? && years >= 3
    badges << ["New Facilitator (<3 years)", "green"] if member_since.present? && years < 3
    badges << ["Spotlighted Facilitator", "gray"] if true || stories_as_spotlighted_facilitator
    badges << ["Events Attended", "blue"] if user.events.any?
    badges << ["Workshop Author", "indigo"] if user.workshops.any? # indigo
    badges << ["Story Author", "rose"] if user.stories_as_creator.any? # pink
    badges << ["Sector Leader", "purple"] if sectorable_items.where(is_leader: true).any?
    badges << ["Blog Contributor", "orange"] if true # || user.respond_to?(:blogs) && user.blogs.any? # red
    badges
  end
end

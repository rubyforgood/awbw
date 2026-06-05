module AuthorCreditable
  extend ActiveSupport::Concern

  AUTHOR_CREDIT_PREFERENCES = %w[full_name first_name_last_initial first_name_only last_name_only anonymous].freeze

  IDEA_FORM_OPTIONS = {
    "I would like my full name published with the story" => "full_name",
    "I would like my first name and last initial published" => "first_name_last_initial",
    "I would like only my first name published" => "first_name_only",
    "I would like only my last name published" => "last_name_only",
    "I do not want my name published with my story" => "anonymous"
  }.freeze

  ADMIN_FORM_OPTIONS = {
    "Full name" => "full_name",
    "First name, last initial" => "first_name_last_initial",
    "First name only" => "first_name_only",
    "Last name only" => "last_name_only",
    "Anonymous" => "anonymous"
  }.freeze

  def author_credit
    free_text = try(:author_name)
    return free_text if free_text.present?
    person = created_by&.person
    case author_credit_preference
    when "full_name" then person&.full_name || "Anonymous"
    when "first_name_last_initial"
      first = person&.first_name
      last_initial = person&.last_name&.first
      first.present? ? "#{first} #{last_initial}." : "Anonymous"
    when "first_name_only" then person&.first_name || "Anonymous"
    when "last_name_only" then person&.last_name || "Anonymous"
    when "anonymous" then "Anonymous"
    else person&.name || "Anonymous"
    end
  end
end

require "rails_helper"

# Every editable varchar(255) column a human types free text into needs a length
# validation. Without one, an over-255 submission raises ActiveRecord::ValueTooLong
# deep in the adapter (STRICT_ALL_TABLES) — a 500 with no reason — instead of a
# friendly inline form error. This locks in `length: { maximum: 255 }` across those
# columns (public, admin, and staff forms). Grant is intentionally excluded (handled
# separately); columns already validated stricter (e.g. CommunityNews#title) are omitted.
RSpec.describe "varchar(255) length validations" do
  LENGTH_LIMITED_COLUMNS = {
    Address => %i[city street_address zip_code district county country phone],
    ContactMethod => %i[value],
    Person => %i[first_name last_name email email_2 legal_first_name pronouns pronunciation
                 best_time_to_call racial_ethnic_identity linked_in_url facebook_url
                 instagram_url youtube_url twitter_url],
    Event => %i[title abbreviation pre_title pre_date_text videoconference_url
                videoconference_label videoconference_passcode hint_dates hint_times
                hint_registration_cost],
    Organization => %i[name email agency_type_other website_url mission_vision_values],
    Affiliation => %i[title],
    Workshop => %i[title full_name],
    WorkshopVariation => %i[name youtube_url],
    WorkshopVariationIdea => %i[name youtube_url],
    WorkshopIdea => %i[title],
    WorkshopSeriesMembership => %i[series_description series_description_spanish theme_name],
    Resource => %i[title],
    VideoRecording => %i[title youtube_url],
    Story => %i[title external_workshop_title website_url youtube_url],
    StoryIdea => %i[external_workshop_title youtube_url],
    CommunityNews => %i[reference_url youtube_url],
    Faq => %i[question],
    Quote => %i[age speaker_name],
    Category => %i[name],
    CategoryType => %i[name display_text],
    Sector => %i[name],
    RegistrationTicketCallout => %i[title subtitle],
    RegistrationTicketCalloutResource => %i[subtitle],
    Report => %i[other_description workshop_name],
    WindowsType => %i[name],
    EventStaff => %i[title]
  }.freeze

  LENGTH_LIMITED_COLUMNS.each do |model, columns|
    columns.each do |column|
      it "#{model} rejects an over-255 #{column} with a readable error" do
        record = model.new(column => "a" * 256)
        record.valid?

        expect(record.errors[column].join).to match(/too long/i)
      end
    end
  end
end

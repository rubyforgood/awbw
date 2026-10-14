require "rails_helper"

# The "Choose what others can see" page saves through PeopleController#update as the
# owner, so every setting it shows must survive the owner params filter and land
# on the person's change log.
RSpec.describe "Choosing what others see on your profile", type: :request do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:switches) do
    %i[profile_is_searchable anonymous_contributions] +
      PersonDecorator::PROFILE_VISIBILITY_GROUPS.values.flat_map(&:keys)
  end

  before do
    Analytics::LifecycleBuffer.store.clear
    sign_in owner_user
  end

  after { Current.user = nil }

  def save_visibility(attributes)
    patch person_path(person), params: { return_to: "visibility", person: attributes }
  end

  # The controller flushes (and clears) the buffer in an after_action, so copy
  # the events as it flushes.
  def buffered_during_request
    events = []
    allow(Analytics::LifecycleBuffer).to receive(:flush) do
      events.concat(Analytics::LifecycleBuffer.store)
      Analytics::LifecycleBuffer.store.clear
    end
    yield
    events
  end

  it "renders a control for every setting" do
    get visibility_person_path(person)

    expect(response).to have_http_status(:ok)
    switches.each { |attribute| expect(response.body).to include(%(name="person[#{attribute}]")) }
    Person::DISPLAY_NAME_PREFERENCES.each do |preference|
      expect(response.body).to include(%(value="#{preference}"))
    end
    expect(response.body).not_to include("person[bio]")
  end

  it "saves every switch flipped, then flipped back" do
    original = switches.index_with { |attribute| person.public_send(attribute) }

    save_visibility(original.transform_values { |value| value ? "0" : "1" })

    expect(response).to redirect_to(person_path(person))
    person.reload
    original.each { |attribute, value| expect(person.public_send(attribute)).to eq(!value), attribute.to_s }

    save_visibility(original.transform_values { |value| value ? "1" : "0" })

    person.reload
    original.each { |attribute, value| expect(person.public_send(attribute)).to eq(value), attribute.to_s }
  end

  it "saves each name choice" do
    Person::DISPLAY_NAME_PREFERENCES.each do |preference|
      save_visibility(display_name_preference: preference)
      expect(person.reload.display_name_preference).to eq(preference)
    end
  end

  it "logs every change to the person's change log as the owner" do
    original = switches.index_with { |attribute| person.public_send(attribute) }

    events = buffered_during_request do
      save_visibility(original.transform_values { |value| value ? "0" : "1" }.merge(display_name_preference: "first_name_only"))
    end

    event = events.find { |e| e[:name] == "update.person" }
    expect(event).to be_present
    expect(event[:user]).to eq(owner_user)
    changes = event.dig(:properties, :changes)
    original.each do |attribute, value|
      expect(changes[attribute.to_s]).to eq(before: value, after: !value), attribute.to_s
    end
    expect(changes["display_name_preference"]).to include(after: "first_name_only")
  end

  it "re-renders the page when the save fails" do
    save_visibility(first_name: "")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Choose what others can see")
  end

  it "is closed to other people" do
    sign_in create(:user)

    get visibility_person_path(person)

    expect(response).to redirect_to(root_path)
  end

  it "is closed in production" do
    allow(Rails.env).to receive(:production?).and_return(true)

    get visibility_person_path(person)

    expect(response).to redirect_to(root_path)
  end
end

require "rails_helper"

RSpec.describe "Communication follow-up flag", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, email: "primary@example.com") }
  let!(:communication) do
    create(:notification, noticeable: person, recipient_email: "primary@example.com",
                          email_subject: "Called about the workshop", kind: "manual_log",
                          channel: "phone", recipient_role: "person", notification_type: 0)
  end

  before { sign_in admin }

  def flag_button
    find("#flag_notification_#{communication.id} button")
  end

  it "flags a communication with a single click, no Edit needed" do
    visit comments_and_communications_path(person_id: person.id)

    expect(flag_button).to have_css("i.fa-regular")

    flag_button.click

    expect(page).to have_css("#flag_notification_#{communication.id} i.fa-solid.text-orange-500", wait: 5)
    expect(communication.reload).to be_flagged
  end

  it "clears the flag with a single click" do
    communication.update!(flagged: true)

    visit comments_and_communications_path(person_id: person.id)

    expect(flag_button).to have_css("i.fa-solid.text-orange-500")

    flag_button.click

    expect(page).to have_css("#flag_notification_#{communication.id} i.fa-regular", wait: 5)
    expect(communication.reload).not_to be_flagged
  end
end

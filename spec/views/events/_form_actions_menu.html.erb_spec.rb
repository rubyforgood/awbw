require "rails_helper"

RSpec.describe "events/_form_actions_menu", type: :view do
  it "includes an Interest form link prefilled to the event and topic" do
    event = create(:event, facilitator_training: true)
    assign(:event, event.decorate)

    render partial: "events/form_actions_menu"

    expect(rendered).to include("Interest form")
    expect(rendered).to include("/topic_subscriptions/new")
    expect(rendered).to include("interested_event_id=#{event.id}")
    expect(rendered).to include("topic=facilitator_trainings")
    expect(rendered).to include("return_to=registrants")
  end
end

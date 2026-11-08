require "rails_helper"

RSpec.describe "events/_form_actions_menu", type: :view do
  it "includes an Interest form link prefilled to the event and topic" do
    event = create(:event, facilitator_training: true)
    assign(:event, event.decorate)

    render partial: "events/form_actions_menu"

    expect(rendered).to include("Interest form")
    expect(rendered).to include("/topic_subscriptions/new")
    expect(rendered).to include("interested_event_id=#{event.id}")
    expect(rendered).to include("topic_key=facilitator_trainings")
    expect(rendered).to include("return_to=registrants")
  end

  it "includes links to offered, publicly fillable survey forms with the event parameter" do
    event = create(:event, facilitator_training: true)
    day_1 = create(:form, role: "day_1_survey", name: "Day 1 Evaluation", slug: "eval-day-1", published: true)
    post_event = create(:form, role: "post_event_survey", name: "Post-Event Survey", slug: "eval-post", published: true)
    assign(:event, event.decorate)

    render partial: "events/form_actions_menu"

    expect(rendered).to include("Day 1 Evaluation")
    expect(rendered).to include("/f/#{day_1.slug}?event=#{event.id}")
    expect(rendered).to include("Post-Event Survey")
    expect(rendered).to include("/f/#{post_event.slug}?event=#{event.id}")
  end
end

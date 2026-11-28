require "rails_helper"

RSpec.describe PageTitleHelper, type: :helper do
  let(:person) { create(:person, first_name: "Pat", last_name: "Example") }

  def visit(controller_name, action, ivars: {})
    allow(helper).to receive(:controller_name).and_return(controller_name)
    allow(helper).to receive(:action_name).and_return(action)
    ivars.each { |name, value| controller.instance_variable_set("@#{name}", value) }
    allow_any_instance_of(PersonDecorator).to receive(:page_title_label) { |decorator| decorator.object.full_name }
  end

  it "names the person as their profile header does" do
    visit("people", "show", ivars: { person: person.decorate })

    expect(helper.page_title).to eq("Pat Example | AWBW")
  end

  it "marks an edit page" do
    visit("people", "edit", ivars: { person: person })

    expect(helper.page_title).to eq("Edit Pat Example | AWBW")
  end

  it "names an event by its abbreviation and dates" do
    event = create(:event, title: "Spring training", abbreviation: "TOS205",
                           start_date: Time.zone.local(2026, 9, 20, 9), end_date: Time.zone.local(2026, 9, 21, 17))
    visit("events", "show", ivars: { event: event })

    expect(helper.page_title).to eq("TOS205 · Sep 20-21, 2026 | AWBW")
  end

  it "names any other record by its title, without markup" do
    workshop = create(:workshop, title: "Paint <b>night</b>")
    visit("workshops", "show", ivars: { workshop: workshop })

    expect(helper.page_title).to eq("Paint night | AWBW")
  end

  it "names the list on an index page" do
    visit("event_registrations", "index")

    expect(helper.page_title).to eq("Event registrations | AWBW")
  end

  it "decodes HTML entities a title was stored with" do
    workshop = create(:workshop, title: "A survivor&#39;s journey")
    visit("workshops", "show", ivars: { workshop: workshop })

    expect(helper.page_title).to eq("A survivor's journey | AWBW")
  end

  it "names a new record's page" do
    visit("people", "new", ivars: { person: Person.new })

    expect(helper.page_title).to eq("New person | AWBW")
  end

  it "adds a custom action to the record's name" do
    visit("people", "all_comments", ivars: { person: person })

    expect(helper.page_title).to eq("Pat Example · all comments | AWBW")
  end

  it "prefers a title the view sets" do
    visit("settings", "edit")
    helper.content_for(:title, "App settings")

    expect(helper.page_title).to eq("App settings | AWBW")
  end
end

# A record's page shows its own Ahoy lifecycle events. Include with `record` and
# `page_path` defined, signed in as whoever should see it.
RSpec.shared_examples "a page with a change log" do
  it "shows the record's change log" do
    create(
      :ahoy_event,
      name: "update.#{record.class.name.underscore}",
      resource_type: record.class.name,
      resource_id: record.id,
      properties: {
        resource_type: record.class.name, resource_id: record.id,
        changes: { "status" => { "before" => "before value", "after" => "after value" } }
      }
    )

    get page_path

    expect(response.body).to include("Change log")
    expect(response.body).to include("after value")
  end

  it "leaves out views and other reads of the record" do
    create(
      :ahoy_event,
      name: "view.#{record.class.name.underscore}",
      resource_type: record.class.name,
      resource_id: record.id,
      properties: { resource_type: record.class.name, resource_id: record.id }
    )

    get page_path

    expect(response.body).to include("No changes recorded yet")
  end

  it "says so rather than disappearing when the record has no tracked activity" do
    get page_path

    expect(response.body).to include("Change log")
    expect(response.body).to include("No changes recorded yet")
  end
end

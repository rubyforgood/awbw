require "rails_helper"

# Categories are assigned through the has_many :through collection setter in
# TagAssignable#assign_associations, which persists immediately and outside the
# record's dirty tracking — so without help they never reach the change log.
# These specs drive the real edit-form flow and read the lifecycle buffer the
# controller flushes to Ahoy, pinning that a category change is now recorded on
# the person's own event.
RSpec.describe "People change log — category assignments", type: :request do
  let(:person) { create(:person) }
  let(:category) { create(:category) }

  before do
    Analytics::LifecycleBuffer.store.clear
    sign_in create(:user, :admin)
  end

  after { Current.user = nil }

  # The controller flushes the buffer (and clears it) in an after_action, so grab
  # a copy as it flushes rather than reading the emptied buffer afterwards.
  def buffered_during_request
    events = []
    allow(Analytics::LifecycleBuffer).to receive(:flush) do
      events.concat(Analytics::LifecycleBuffer.store)
      Analytics::LifecycleBuffer.store.clear
    end
    yield
    events
  end

  def person_association_changes(events)
    event = events.find { |e| e[:name] == "update.person" }
    event&.dig(:properties, :association_changes)
  end

  it "records a category added through the edit form on the person's change log" do
    events = buffered_during_request do
      patch person_path(person), params: {
        person: { category_ids: [ category.id ], managed_category_type_ids: [ category.category_type_id ] }
      }
    end

    added = person_association_changes(events)&.dig(:categories)
    expect(added).to be_present
    expect(added.first).to include(action: "added", type: "Category", id: category.id)
  end

  it "records a category removed through the edit form on the person's change log" do
    create(:categorizable_item, categorizable: person, category: category)

    events = buffered_during_request do
      patch person_path(person), params: {
        person: { category_ids: [], managed_category_type_ids: [ category.category_type_id ] }
      }
    end

    removed = person_association_changes(events)&.dig(:categories)
    expect(removed).to be_present
    expect(removed.first).to include(action: "removed", type: "Category", id: category.id)
  end

  it "records nothing when the category set is unchanged" do
    create(:categorizable_item, categorizable: person, category: category)

    events = buffered_during_request do
      patch person_path(person), params: {
        person: { category_ids: [ category.id ], managed_category_type_ids: [ category.category_type_id ] }
      }
    end

    expect(person_association_changes(events)).to be_nil
  end
end

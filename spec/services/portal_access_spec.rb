require "rails_helper"

RSpec.describe PortalAccess do
  let(:person) { create(:person) }
  let(:user) { person.user }
  let(:last_year) { Date.current.prev_year }

  def lapsed?(account = user)
    described_class.new(account.reload).lapsed?
  end

  def facilitator(**attrs)
    create(:affiliation, person: person, title: Affiliation::FACILITATOR_TITLE, **attrs)
  end

  def ended
    { start_date: last_year.prev_year, end_date: last_year }
  end

  describe "#lapsed?" do
    it "is false for a person with no memberships or facilitator affiliations" do
      expect(lapsed?).to be(false)
    end

    it "is false for a user without a person" do
      expect(lapsed?(create(:user, person: nil))).to be(false)
    end

    it "ignores job affiliations" do
      create(:affiliation, person: person, title: "Counselor", **ended)

      expect(lapsed?).to be(false)
    end

    it "is false with an active facilitator affiliation" do
      facilitator(start_date: last_year)

      expect(lapsed?).to be(false)
    end

    it "is false with an upcoming facilitator affiliation" do
      facilitator(start_date: Date.current.next_month)

      expect(lapsed?).to be(false)
    end

    it "is true when every facilitator affiliation has ended" do
      facilitator(**ended)

      expect(lapsed?).to be(true)
    end

    it "is true when the only facilitator affiliation is flagged inactive" do
      facilitator(start_date: last_year).update!(inactive: true, inactive_supplied: true)

      expect(lapsed?).to be(true)
    end

    it "is false when one of several facilitator affiliations is still active" do
      facilitator(**ended)
      facilitator(start_date: last_year)

      expect(lapsed?).to be(false)
    end

    it "is false with an active membership" do
      create(:membership, person: person)

      expect(lapsed?).to be(false)
    end

    it "is true when every membership is cancelled" do
      create(:membership, :cancelled, person: person)

      expect(lapsed?).to be(true)
    end

    it "is false for a cancelled member who still facilitates" do
      create(:membership, :cancelled, person: person)
      facilitator(start_date: last_year)

      expect(lapsed?).to be(false)
    end

    it "is false for a lapsed facilitator with an active membership" do
      facilitator(**ended)
      create(:membership, person: person)

      expect(lapsed?).to be(false)
    end

    it "ignores memberships while memberships are disabled" do
      create(:membership, :cancelled, person: person)
      allow(Membership).to receive(:enabled?).and_return(false)

      expect(lapsed?).to be(false)
    end

    it "is false for a super user" do
      facilitator(**ended)
      user.update!(super_user: true)

      expect(lapsed?).to be(false)
    end
  end

  describe ".lapsed_people (SQL ↔ Ruby agree)" do
    let(:people) do
      {
        none: create(:person),
        job_only: create(:person),
        active_facilitator: create(:person),
        upcoming_facilitator: create(:person),
        ended_facilitator: create(:person),
        mixed_facilitator: create(:person),
        member: create(:person),
        cancelled_member: create(:person),
        cancelled_member_facilitating: create(:person),
        ended_facilitator_member: create(:person)
      }
    end

    before do
      create(:affiliation, person: people[:job_only], title: "Counselor", **ended)
      create(:affiliation, person: people[:active_facilitator], start_date: last_year)
      create(:affiliation, person: people[:upcoming_facilitator], start_date: Date.current.next_month)
      create(:affiliation, person: people[:ended_facilitator], **ended)
      create(:affiliation, person: people[:mixed_facilitator], **ended)
      create(:affiliation, person: people[:mixed_facilitator], start_date: last_year)
      create(:membership, person: people[:member])
      create(:membership, :cancelled, person: people[:cancelled_member])
      create(:membership, :cancelled, person: people[:cancelled_member_facilitating])
      create(:affiliation, person: people[:cancelled_member_facilitating], start_date: last_year)
      create(:affiliation, person: people[:ended_facilitator_member], **ended)
      create(:membership, person: people[:ended_facilitator_member])
    end

    [ true, false ].each do |enabled|
      it "matches #lapsed? for every person when memberships are #{enabled ? "enabled" : "disabled"}" do
        allow(Membership).to receive(:enabled?).and_return(enabled)

        expected = people.values.select { |p| described_class.new(p.user.reload).lapsed? }.map(&:id).sort

        expect(described_class.lapsed_people.where(id: people.values.map(&:id)).ids.sort).to eq(expected)
        expect(expected).to include(people[:ended_facilitator].id)
      end
    end
  end
end

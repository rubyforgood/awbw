require "rails_helper"

RSpec.describe EventChecklist do
  subject(:checklist) { described_class.new(EventDashboard.new(event)) }

  def item(key)
    checklist.items.find { |i| i.key == key }
  end

  describe "structure" do
    let(:event) { create(:event) }

    it "lists items in lifecycle order across the phases" do
      keys = checklist.items.map(&:key)
      expect(keys.first(4)).to eq(%i[ setup_forms setup_callouts setup_publish setup_event_type ])
      expect(keys.last(2)).to eq(%i[ review_reports post_event_survey ])
    end

    it "keeps the user's scholarship sub-order (issue -> funders -> agreements -> $0 -> tasks)" do
      scholarship_keys = %i[ issue_scholarships set_scholarship_funders follow_up_agreements
                             fix_zero_scholarships complete_scholarship_tasks ]
      ordered = checklist.items.map(&:key).select { |k| scholarship_keys.include?(k) }
      expect(ordered).to eq(scholarship_keys)
    end

    it "always keeps the post-event survey as an unbuilt placeholder" do
      expect(item(:post_event_survey).kind).to eq(:placeholder)
      expect(item(:post_event_survey)).to be_not_relevant
    end

    it "models review reports as a standing action, not a done-able task" do
      expect(item(:review_reports).kind).to eq(:action)
    end
  end

  describe "before the event, with a registrant" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:registrant) { create(:person) }

    before { create(:event_registration, event: event, registrant: registrant, status: "registered") }

    it "flags unpaid registrants as a reminder to-do" do
      fees = item(:collect_registration_fees)
      expect(fees).to be_todo
      expect(fees.count).to eq(1)
      expect(fees.registrants).to include(registrant)
      expect(fees.money_cents).to eq(10_000)
      expect(fees.action_path).to include("preview_reminder", "payment_status=unpaid")
    end

    it "surfaces registrations with no organization via the roster unlinked filter" do
      link = item(:link_organizations)
      expect(link).to be_todo
      expect(link.count).to eq(1)
      expect(link.action_path).to include("org_status=unlinked")
    end

    it "does not surface during/after items before the event happens" do
      %i[ record_attendance reconcile_ce_hours send_completion_certificates review_reports ].each do |key|
        expect(item(key)).to be_not_relevant
      end
    end
  end

  describe "a free event" do
    let(:event) { create(:event, cost_cents: 0) }

    before { create(:event_registration, event: event, registrant: create(:person), status: "registered") }

    it "hides the fee and scholarship items" do
      %i[ collect_registration_fees issue_scholarships set_scholarship_funders
          follow_up_agreements fix_zero_scholarships complete_scholarship_tasks ].each do |key|
        expect(item(key)).to be_not_relevant
      end
    end
  end

  describe "after the event" do
    let(:event) { create(:event, :ended, cost_cents: 10_000) }

    before { create(:event_registration, event: event, registrant: create(:person), status: "registered") }

    it "surfaces recording attendance for registrants with no outcome" do
      attendance = item(:record_attendance)
      expect(attendance).to be_todo
      expect(attendance.count).to eq(1)
      expect(attendance.action_path).to include("attendance_status=registered")
    end

    it "turns reviewing reports into a standing to-do pointing at the stats hub" do
      reports = item(:review_reports)
      expect(reports).to be_todo
      expect(reports.action_path).to eq(Rails.application.routes.url_helpers.statistics_events_path)
    end
  end

  describe "progress buckets" do
    let(:event) { create(:event, :publicly_visible, published: true) }

    it "counts done vs relevant over trackable items only and resolves the placeholder" do
      expect(checklist.relevant_count).to be_positive
      expect(checklist.done_count).to be <= checklist.relevant_count
      expect(checklist.resolved_items).to include(item(:post_event_survey))
      expect(item(:setup_publish)).to be_done
    end
  end
end

require "rails_helper"

RSpec.describe WorkshopLog do
  describe "associations" do
    it { should belong_to(:created_by).optional }
    it { should belong_to(:organization).optional }
    it { should belong_to(:windows_type).optional }
    it { should belong_to(:workshop).optional }
    it { should have_many(:bookmarks) }
    it { should have_many(:notifications) }
    it { should have_many(:report_form_field_answers).dependent(:destroy) }
    it { should have_many(:gallery_assets) }
    it { should have_many(:sectorable_items) }
    it { should have_many(:quotable_item_quotes) }
    it { should have_many(:assets) }
  end

  describe "validations" do
    it "is valid with a workshop" do
      workshop_log = build(:workshop_log)
      expect(workshop_log).to be_valid
    end

    it "is valid with external_workshop_title and no workshop" do
      workshop_log = build(:workshop_log, workshop: nil, external_workshop_title: "Community Art Workshop")
      expect(workshop_log).to be_valid
    end

    it "is invalid without workshop or external_workshop_title" do
      workshop_log = build(:workshop_log, workshop: nil, external_workshop_title: nil)
      expect(workshop_log).not_to be_valid
      expect(workshop_log.errors[:base]).to include("Please select a workshop or provide an external workshop title")
    end

    it "requires workshop_held_on" do
      workshop_log = build(:workshop_log, workshop_held_on: nil)
      expect(workshop_log).not_to be_valid
      expect(workshop_log.errors[:workshop_held_on]).to include("can't be blank")
    end

    it "requires attendance fields to be non-negative integers" do
      workshop_log = build(:workshop_log, children_first_time: -1)
      expect(workshop_log).not_to be_valid
      expect(workshop_log.errors[:children_first_time]).to be_present
    end
  end

  describe "#workshop_title" do
    it "returns workshop title when workshop is present" do
      workshop = create(:workshop, title: "Test Workshop")
      workshop_log = build(:workshop_log, workshop: workshop)
      expect(workshop_log.workshop_title).to eq("Test Workshop")
    end

    it "returns external_workshop_title when workshop is not present" do
      workshop_log = build(:workshop_log, workshop: nil, external_workshop_title: "External Workshop")
      expect(workshop_log.workshop_title).to eq("External Workshop")
    end

    it "returns empty string when neither workshop nor external_workshop_title is present" do
      workshop_log = build(:workshop_log, workshop: nil, external_workshop_title: nil)
      expect(workshop_log.workshop_title).to eq("")
    end
  end

  describe "#total_attendance" do
    it "sums all attendance fields" do
      workshop_log = build(:workshop_log,
        children_first_time: 1, children_ongoing: 2,
        teens_first_time: 3, teens_ongoing: 4,
        adults_first_time: 5, adults_ongoing: 6)
      expect(workshop_log.total_attendance).to eq(21)
    end
  end

  describe "#totals" do
    it "returns breakdown by age group and type" do
      workshop_log = build(:workshop_log,
        children_first_time: 1, children_ongoing: 2,
        teens_first_time: 3, teens_ongoing: 4,
        adults_first_time: 5, adults_ongoing: 6)

      result = workshop_log.totals
      expect(result[:children]).to eq(3)
      expect(result[:teens]).to eq(7)
      expect(result[:adults]).to eq(11)
      expect(result[:first_time]).to eq(9)
      expect(result[:ongoing]).to eq(12)
      expect(result[:overall]).to eq(21)
    end
  end

  describe "#title" do
    it "returns formatted title with workshop name" do
      workshop = create(:workshop, title: "Art Therapy")
      workshop_log = build(:workshop_log, workshop: workshop)
      expect(workshop_log.title).to eq("Workshop Log - Art Therapy")
    end

    it "returns nil when no workshop" do
      workshop_log = build(:workshop_log, workshop: nil, external_workshop_title: nil)
      expect(workshop_log.title).to be_nil
    end
  end

  describe "scopes" do
    describe ".search" do
      let(:organization) { create(:organization) }
      let(:workshop) { create(:workshop) }
      let(:user) { create(:user) }

      it "filters by organization_id" do
        log = create(:workshop_log, organization: organization)
        other_log = create(:workshop_log)

        results = WorkshopLog.search(organization_id: organization.id)
        expect(results).to include(log)
        expect(results).not_to include(other_log)
      end

      it "filters by workshop_id" do
        log = create(:workshop_log, workshop: workshop)
        other_log = create(:workshop_log)

        results = WorkshopLog.search(workshop_id: workshop.id)
        expect(results).to include(log)
        expect(results).not_to include(other_log)
      end

      it "filters by created_by_id" do
        log = create(:workshop_log, created_by: user)
        other_log = create(:workshop_log)

        results = WorkshopLog.search(created_by_id: user.id)
        expect(results).to include(log)
        expect(results).not_to include(other_log)
      end

      it "returns all when no filters" do
        log1 = create(:workshop_log)
        log2 = create(:workshop_log)

        results = WorkshopLog.search({})
        expect(results).to include(log1, log2)
      end
    end
  end

  describe "callbacks" do
    describe "#update_workshop_log_count" do
      it "updates workshop led_count after create" do
        workshop = create(:workshop, led_count: 0)
        create(:workshop_log, workshop: workshop)

        expect(workshop.reload.led_count).to eq(1)
      end
    end
  end

  describe "updating does not fail due to notifications" do
    it "saves successfully even when associated notifications exist" do
      workshop_log = create(:workshop_log)
      create(:notification,
             noticeable: workshop_log,
             kind: :workshop_log_submitted_fyi,
             recipient_role: :admin,
             recipient_email: "test@example.com",
             notification_type: 0)

      workshop_log.reload
      workshop_log.children_ongoing = 5
      expect(workshop_log.save).to be true
    end

    it "does not create a notification on save" do
      workshop_log = create(:workshop_log)
      expect { workshop_log.update!(children_ongoing: 3) }
        .not_to change { Notification.count }
    end
  end

  describe "is a standalone model" do
    it "inherits from ApplicationRecord, not Report" do
      expect(WorkshopLog.superclass).to eq(ApplicationRecord)
    end

    it "uses the workshop_logs table" do
      expect(WorkshopLog.table_name).to eq("workshop_logs")
    end
  end
end

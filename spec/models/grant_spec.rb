require "rails_helper"

RSpec.describe Grant, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:funder).optional }
    it { is_expected.to belong_to(:created_by).class_name("User").optional }
    it { is_expected.to belong_to(:updated_by).class_name("User").optional }
    it { is_expected.to have_many(:scholarships).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:sectorable_items).dependent(:destroy) }
    it { is_expected.to have_many(:sectors).through(:sectorable_items) }
    it { is_expected.to have_many(:categorizable_items).dependent(:destroy) }
    it { is_expected.to have_many(:categories).through(:categorizable_items) }
  end

  describe "tagging" do
    let(:sector) { create(:sector) }
    let(:category) { create(:category) }

    it "attaches sectors and categories assigned by id on a new record" do
      grant = create(:grant, sector_ids: [ sector.id ], category_ids: [ category.id ])

      expect(grant.reload.sectors).to contain_exactly(sector)
      expect(grant.categories).to contain_exactly(category)
    end

    it "updates sectors and categories by id on an existing record" do
      grant = create(:grant, sectors: [ sector ])
      other_sector = create(:sector)

      grant.update!(sector_ids: [ other_sector.id ], category_ids: [ category.id ])

      expect(grant.reload.sectors).to contain_exactly(other_sector)
      expect(grant.categories).to contain_exactly(category)
    end

    describe ".sector_names_all / .category_names_all" do
      it "finds grants carrying the given tags" do
        tagged = create(:grant, sectors: [ sector ], categories: [ category ])
        create(:grant)

        expect(Grant.sector_names_all(sector.name)).to contain_exactly(tagged)
        expect(Grant.category_names_all(category.name)).to contain_exactly(tagged)
      end
    end

    it "responds to a no-op published scope covering every grant" do
      grant = create(:grant)
      expect(Grant.published).to include(grant)
    end
  end

  describe "planned_giving" do
    it "defaults to false" do
      expect(Grant.new.planned_giving).to be(false)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than_or_equal_to(0) }

    it "is valid with an organization funder" do
      expect(build(:grant)).to be_valid
    end

    it "is valid with a person funder" do
      expect(build(:grant, :donated_by_person)).to be_valid
    end

    it "attaches the missing-funder error to funder_sgid so the form field shows it" do
      grant = build(:grant, funder: nil)

      expect(grant).not_to be_valid
      expect(grant.errors[:funder_sgid]).to include("must be selected")
      expect(grant.errors.full_messages).to include("Funder must be selected")
    end

    describe "amount cannot drop below scholarships already issued" do
      it "is invalid when the amount is reduced below the total awarded" do
        grant = create(:grant, amount_cents: 100_000)
        create(:scholarship, grant:, amount_cents: 60_000)

        grant.amount_cents = 50_000
        expect(grant).not_to be_valid
        expect(grant.errors[:amount_cents]).to include("can't be less than the $600 already awarded in scholarships")
      end

      it "is valid when the amount equals the total awarded" do
        grant = create(:grant, amount_cents: 100_000)
        create(:scholarship, grant:, amount_cents: 60_000)

        grant.amount_cents = 60_000
        expect(grant).to be_valid
      end

      it "is valid when the amount stays above the total awarded" do
        grant = create(:grant, amount_cents: 100_000)
        create(:scholarship, grant:, amount_cents: 60_000)

        grant.amount_cents = 70_000
        expect(grant).to be_valid
      end

      it "is valid for a new grant with no scholarships" do
        expect(build(:grant, amount_cents: 0)).to be_valid
      end
    end
  end

  describe "money accessors" do
    it "exposes the amount in dollars" do
      expect(build(:grant, amount_cents: 250_000).amount_dollars).to eq(2_500)
    end

    it "stores dollars as cents" do
      grant = build(:grant)
      grant.amount_dollars = "1234.56"
      expect(grant.amount_cents).to eq(123_456)
    end
  end

  describe "#funder_sgid" do
    it "round-trips a funder through a signed global id" do
      organization = create(:organization)
      grant = build(:grant)
      grant.funder_sgid = organization.to_signed_global_id.to_s
      expect(grant.funder).to eq(organization)
      expect(GlobalID::Locator.locate_signed(grant.funder_sgid)).to eq(organization)
    end
  end

  describe "list accessors" do
    let(:grant) { build(:grant, eligibility_criteria: "One\n\n  Two  \n", tasks: "A\nB") }

    it "splits eligibility criteria into a trimmed list" do
      expect(grant.eligibility_criteria_list).to eq([ "One", "Two" ])
    end

    it "splits tasks into a list" do
      expect(grant.task_list).to eq([ "A", "B" ])
    end
  end

  describe "#name_with_funder" do
    it "appends the funder name in parens" do
      organization = build(:organization, name: "Acme Foundation")
      grant = build(:grant, name: "Spring Fund", funder: organization)
      expect(grant.name_with_funder).to eq("Spring Fund (Acme Foundation)")
    end

    it "falls back to the bare name when there is no funder" do
      grant = build(:grant, name: "Spring Fund")
      allow(grant).to receive(:funder_name).and_return(nil)
      expect(grant.name_with_funder).to eq("Spring Fund")
    end
  end

  describe "budget helpers" do
    let(:grant) { create(:grant, amount_cents: 100_000) }

    it "sums awarded scholarships" do
      create(:scholarship, grant:, amount_cents: 30_000)
      create(:scholarship, grant:, amount_cents: 20_000)
      expect(grant.scholarships_total_cents).to eq(50_000)
    end

    it "sums the preloaded association without an extra query" do
      create(:scholarship, grant:, amount_cents: 30_000)
      create(:scholarship, grant:, amount_cents: 20_000)
      preloaded = Grant.includes(:scholarships).find(grant.id)

      queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        queries << payload[:sql] unless payload[:name] == "SCHEMA"
      end
      total = preloaded.scholarships_total_cents
      ActiveSupport::Notifications.unsubscribe(subscriber)

      expect(total).to eq(50_000)
      expect(queries).to be_empty
    end

    it "reports remaining funds" do
      create(:scholarship, grant:, amount_cents: 40_000)
      expect(grant.remaining_cents).to eq(60_000)
      expect(grant.remaining_dollars).to eq(600)
    end
  end

  describe ".with_funds_remaining" do
    it "includes grants with unallocated funds and excludes fully-allocated ones" do
      has_funds = create(:grant, amount_cents: 100_000)
      create(:scholarship, grant: has_funds, amount_cents: 40_000)
      untouched = create(:grant, amount_cents: 50_000)
      exhausted = create(:grant, amount_cents: 30_000)
      create(:scholarship, grant: exhausted, amount_cents: 30_000)

      expect(Grant.with_funds_remaining).to contain_exactly(has_funds, untouched)
    end
  end

  describe ".fully_issued" do
    it "includes fully-allocated grants and excludes ones with funds left" do
      has_funds = create(:grant, amount_cents: 100_000)
      create(:scholarship, grant: has_funds, amount_cents: 40_000)
      exhausted = create(:grant, amount_cents: 30_000)
      create(:scholarship, grant: exhausted, amount_cents: 30_000)

      expect(Grant.fully_issued).to contain_exactly(exhausted)
    end
  end

  describe "task-completion scopes" do
    it "separates all-completed grants from those with outstanding tasks" do
      all_done = create(:grant)
      create(:scholarship, grant: all_done, tasks_completed: true)
      mixed = create(:grant)
      create(:scholarship, grant: mixed, tasks_completed: true)
      create(:scholarship, grant: mixed, tasks_completed: false)
      no_scholarships = create(:grant)

      expect(Grant.all_tasks_completed).to contain_exactly(all_done)
      expect(Grant.tasks_outstanding).to contain_exactly(mixed)
      expect(Grant.all_tasks_completed).not_to include(no_scholarships)
    end

    it "ignores grant-less scholarships when computing completion" do
      # A grant-less, incomplete scholarship has a NULL grant_id. Left in the
      # NOT IN subquery it would make all_tasks_completed match nothing.
      create(:scholarship, grant: nil, tasks_completed: false)
      all_done = create(:grant)
      create(:scholarship, grant: all_done, tasks_completed: true)

      expect(Grant.all_tasks_completed).to contain_exactly(all_done)
    end
  end

  describe ".selectable_for" do
    it "lists grants with funds remaining" do
      with_funds = create(:grant, amount_cents: 100_000)
      exhausted = create(:grant, amount_cents: 30_000)
      create(:scholarship, grant: exhausted, amount_cents: 30_000)

      expect(Grant.selectable_for(Scholarship.new)).to include(with_funds)
      expect(Grant.selectable_for(Scholarship.new)).not_to include(exhausted)
    end

    it "keeps the scholarship's connected grant even when it is fully allocated" do
      grant = create(:grant, amount_cents: 30_000)
      scholarship = create(:scholarship, grant:, amount_cents: 30_000)

      expect(grant.remaining_cents).to eq(0)
      expect(Grant.selectable_for(scholarship)).to include(grant)
    end

    it "does not duplicate the connected grant when it still has funds" do
      grant = create(:grant, amount_cents: 100_000)
      scholarship = create(:scholarship, grant:, amount_cents: 10_000)

      expect(Grant.selectable_for(scholarship).count(grant)).to eq(1)
    end
  end
end

require "rails_helper"

RSpec.describe Event, type: :model do
  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
    it { should validate_numericality_of(:cost_cents).is_greater_than_or_equal_to(0).allow_nil }
  end

  describe "#ended?" do
    it "returns true when end_date is in the past" do
      event = build(:event, end_date: 1.day.ago)
      expect(event.ended?).to be true
    end

    it "returns false when end_date is in the future" do
      event = build(:event, end_date: 1.day.from_now)
      expect(event.ended?).to be false
    end
  end

  describe "#registerable?" do
    it "returns true when registration_close_date is in the future" do
      event = build(:event, published: true, registration_close_date: 5.days.from_now)
      expect(event.registerable?).to be true
    end

    it "returns true when registration_close_date is nil" do
      event = build(:event, published: true, registration_close_date: nil)
      expect(event.registerable?).to be true
    end

    it "returns false when registration_close_date is in the past" do
      event = build(:event, published: true, registration_close_date: 1.day.ago)
      expect(event.registerable?).to be false
    end

    it "returns true when unpublished but registration_close_date is in the future" do
      event = build(:event, published: false, registration_close_date: 5.days.from_now)
      expect(event.registerable?).to be true
    end

    it "returns true when unpublished and registration_close_date is nil" do
      event = build(:event, published: false, registration_close_date: nil)
      expect(event.registerable?).to be true
    end

    it "returns false when event has ended even with future registration_close_date" do
      event = build(:event, end_date: 1.day.ago, registration_close_date: 5.days.from_now)
      expect(event.registerable?).to be false
    end
  end

  describe "#active_registration_for" do
    let(:event) { create(:event) }
    let(:person) { create(:person) }

    it "returns nil when person is nil" do
      expect(event.active_registration_for(nil)).to be_nil
    end

    it "returns nil when person has no registration" do
      expect(event.active_registration_for(person)).to be_nil
    end

    it "returns the registration when person has an active registration" do
      reg = create(:event_registration, event: event, registrant: person, status: "registered")
      expect(event.active_registration_for(person)).to eq(reg)
    end

    it "returns nil when person has a cancelled registration" do
      create(:event_registration, event: event, registrant: person, status: "cancelled")
      expect(event.active_registration_for(person)).to be_nil
    end
  end

  describe "#actively_registered?" do
    let(:event) { create(:event) }
    let(:person) { create(:person) }

    it "returns false when person is nil" do
      expect(event.actively_registered?(nil)).to be false
    end

    it "returns true when person has an active registration" do
      create(:event_registration, event: event, registrant: person, status: "registered")
      expect(event.actively_registered?(person)).to be true
    end

    it "returns false when person has a cancelled registration" do
      create(:event_registration, event: event, registrant: person, status: "cancelled")
      expect(event.actively_registered?(person)).to be false
    end

    it "returns false when person has no registration" do
      expect(event.actively_registered?(person)).to be false
    end
  end

  describe "cost as virtual attribute of cost_cents" do
    let(:event) { create(:event, cost_cents: 5431) }

    describe "#cost" do
      it "represents cost in dollar amount" do
        expect(event.cost).to eq(54.31)
      end
    end

    describe "#cost=" do
      it "converts float cost in dollars to cost_cents field" do
        event.cost = 10.99
        expect(event.cost_cents).to eq(1099)
      end

      it "converts string cost in dollars to cost_cents field" do
        event.cost = "10.99"
        expect(event.cost_cents).to eq(1099)
      end
    end
  end

  describe "#build_public_registration_form" do
    let!(:default_form) { create(:form, name: "Short Event Registration") }
    let!(:extended_form) { create(:form, name: "Extended Event Registration") }

    it "links the default registration form by default" do
      event = create(:event, public_registration_enabled: true)
      expect(event.event_forms.registration.exists?).to be true
      expect(event.registration_form).to eq(default_form)
    end

    it "links the extended registration form when title contains training" do
      event = create(:event, title: "Facilitator Training", public_registration_enabled: true)
      expect(event.event_forms.registration.exists?).to be true
      expect(event.registration_form).to eq(extended_form)
    end

    it "does not link a form when public_registration_enabled is false" do
      event = create(:event, public_registration_enabled: false)
      expect(event.event_forms.registration.exists?).to be false
    end

    it "links a form when toggled to true on update" do
      event = create(:event, public_registration_enabled: false)
      event.update!(public_registration_enabled: true)
      expect(event.event_forms.registration.exists?).to be true
      expect(event.registration_form).to eq(default_form)
    end

    it "does not duplicate the link if one already exists" do
      event = create(:event, public_registration_enabled: true)
      expect(event.event_forms.registration.count).to eq(1)

      event.update!(title: "Updated title")
      expect(event.event_forms.registration.count).to eq(1)
    end
  end

  describe "#registration_form" do
    it "returns the form linked with registration role" do
      form = create(:form, name: "My Registration")
      event = create(:event)
      create(:event_form, event: event, form: form, role: "registration")
      expect(event.registration_form).to eq(form)
    end

    it "returns nil when no registration form is linked" do
      event = create(:event)
      expect(event.registration_form).to be_nil
    end
  end

  describe "#scholarship_form" do
    it "returns the form linked with scholarship role" do
      form = create(:form, name: "Scholarship App")
      event = create(:event)
      create(:event_form, event: event, form: form, role: "scholarship")
      expect(event.scholarship_form).to eq(form)
    end
  end

  describe '.search_by_params' do
    let!(:art_event) { create(:event, title: 'Art Workshop Showcase', description: 'Annual art exhibition') }
    let!(:music_event) { create(:event, title: 'Music Therapy Session', description: 'Healing through music') }

    it 'returns all when no params' do
      results = Event.search_by_params({})
      expect(results).to include(art_event, music_event)
    end

    it 'filters by query matching title' do
      results = Event.search_by_params(query: 'Art Workshop')
      expect(results).to include(art_event)
      expect(results).not_to include(music_event)
    end

    it 'filters by query matching description' do
      results = Event.search_by_params(query: 'Healing')
      expect(results).to include(music_event)
      expect(results).not_to include(art_event)
    end

    it 'returns empty for non-matching query' do
      results = Event.search_by_params(query: 'nonexistent')
      expect(results).not_to include(art_event, music_event)
    end
  end
end

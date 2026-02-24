require "rails_helper"

RSpec.describe EventRegistration, type: :model do
  subject { create(:event_registration) }

  describe "associations" do
    it { should belong_to(:event).required }
    it { should belong_to(:registrant).required }
    it { should have_many(:comments).dependent(:destroy) }
  end

  describe '.search_by_params' do
    let(:person_alice) { create(:person, first_name: 'Alice', last_name: 'Smith') }
    let(:person_bob) { create(:person, first_name: 'Bob', last_name: 'Jones') }
    let(:event_art) { create(:event, title: 'Art Workshop') }
    let(:event_music) { create(:event, title: 'Music Session') }

    let!(:reg_alice_art) { create(:event_registration, registrant: person_alice, event: event_art) }
    let!(:reg_bob_music) { create(:event_registration, registrant: person_bob, event: event_music) }

    it 'returns all when no params' do
      results = EventRegistration.search_by_params({})
      expect(results).to include(reg_alice_art, reg_bob_music)
    end

    it 'filters by registrant_id' do
      results = EventRegistration.search_by_params(registrant_id: person_alice.id)
      expect(results).to include(reg_alice_art)
      expect(results).not_to include(reg_bob_music)
    end

    it 'filters by event_id' do
      results = EventRegistration.search_by_params(event_id: event_music.id)
      expect(results).to include(reg_bob_music)
      expect(results).not_to include(reg_alice_art)
    end

    it 'chains registrant_id and event_id filters' do
      results = EventRegistration.search_by_params(registrant_id: person_alice.id, event_id: event_art.id)
      expect(results).to include(reg_alice_art)
      expect(results).not_to include(reg_bob_music)
    end
  end
end

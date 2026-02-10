require 'rails_helper'

RSpec.describe WorkshopLog do
  # pending "add some examples to (or delete) #{__FILE__}"

  it 'is a type of Report' do
    expect(build(:workshop_log)).to be_a(Report)
  end

  describe 'associations' do
    # Explicitly defined here
    it { should belong_to(:workshop) }
    it { should belong_to(:user) } # Inherited via Report but also explicit?
    it { should belong_to(:organization) } # Inherited via Report but also explicit?
    it { should have_many(:media_files) }

    # Inherited from Report
    # it { should belong_to(:windows_type) }
    # it { should belong_to(:owner).optional } # Should be Workshop in this case
    # it { should have_many(:report_form_field_answers).dependent(:destroy) }
    # ... other Report associations
  end

  describe 'validations' do
    # Inherited from Report
    # Add specific WorkshopLog validations if any
  end

  it 'is valid with valid attributes' do
    # Note: Factory needs associations uncommented for create
    # expect(build(:workshop_log)).to be_valid
  end

  describe '#workshop_title' do
    it 'returns workshop title when workshop is present' do
      workshop = create(:workshop, title: 'Test Workshop')
      workshop_log = build(:workshop_log, workshop: workshop, owner: nil)
      expect(workshop_log.workshop_title).to eq('Test Workshop')
    end

    it 'returns external_workshop_title when workshop is not present' do
      workshop_log = build(:workshop_log, workshop: nil, owner: nil, external_workshop_title: 'External Workshop')
      expect(workshop_log.workshop_title).to eq('External Workshop')
    end

    it 'returns empty string when neither workshop nor external_workshop_title is present' do
      workshop_log = build(:workshop_log, workshop: nil, owner: nil, external_workshop_title: nil)
      expect(workshop_log.workshop_title).to eq('')
    end
  end

  # Add tests for specific methods like #num_ongoing, #num_first_time, callbacks
  describe 'callbacks' do
    # Test after_save :update_workshop_log_count
  end
end

class FormBuilder < ApplicationRecord
  belongs_to :windows_type
  has_many :forms, as: :owner

  # Validations
  validates :name, presence: true

  # Nested attributes
  accepts_nested_attributes_for :forms

  scope :workshop_logs, -> { where('name LIKE ?', '%Log%') }
  scope :monthly, -> { where('name LIKE ?', '%monthly%') }

  def form_fields
    forms[0].form_fields if forms.any?
  end

  def report_type
    case name
    when 'Children\'s Monthly Report'
      'MonthlyReport'
    when 'Adult Monthly Report'
      'MonthlyReport'
    when 'Family Windows Workshop Log'
      'WorkshopLog'
    when 'Adult Worksohp Log'
      'WorkshopLog'
    when 'Adult Workshop Log'
      'WorkshopLog'
    when 'Children\'s Workshop Log'
      'WorkshopLog'
    when 'Adult Log Entry'
      'WorkshopLog'
    when 'Children\'s Log Entry'
      'WorkshopLog'
    when 'Family Log Entry'
      'WorkshopLog'
    else
      'Report'
    end
  end

  def family_workshop_log?
    name.include?('Workshop') && name == 'Family Windows Workshop Log'
  end
end

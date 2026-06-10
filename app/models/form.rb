class Form < ApplicationRecord
  belongs_to :owner, polymorphic: true, optional: true
  has_many :form_fields, dependent: :destroy, inverse_of: :form
  has_many :event_forms, dependent: :destroy
  has_many :user_forms
  has_many :form_submissions
  has_many :reports, as: :owner
  # has_many through
  has_many :events, through: :event_forms

  # Nested attributes
  accepts_nested_attributes_for :form_fields, allow_destroy: true,
    reject_if: proc { |attrs| attrs["name"].blank? && attrs["id"].blank? }

  scope :standalone, -> { where(owner_id: nil, owner_type: nil) }

  def display_name
    name.presence || (owner ? "#{owner.try(:name)} Form" : "New Form")
  end

  # The top-level Section grouping of subsections. Each entry looks like
  #   { "label" => "About you", "subsections" => ["person_identifier", ...] }
  # An empty/absent value means the form has no Sections and renders flat.
  def section_groups
    Array(sections).map { |group| group.to_h.with_indifferent_access }
  end

  def sections?
    section_groups.any?
  end

  # The Section label a given subsection belongs to, or nil when it is not
  # grouped under any Section.
  def section_label_for_subsection(subsection_key)
    return if subsection_key.blank?

    group = section_groups.find { |g| Array(g[:subsections]).include?(subsection_key.to_s) }
    group && group[:label].presence
  end

  # Rebuilds the Section grouping from a { subsection_key => label } map,
  # preserving subsection order and merging subsections that share a label.
  # Blank labels leave a subsection ungrouped.
  def assign_section_groups!(labels)
    grouped = {}
    Array(subsections).each do |key|
      label = labels[key.to_s].to_s.strip
      next if label.blank?

      (grouped[label] ||= []) << key.to_s
    end

    update!(sections: grouped.map { |label, subs| { "label" => label, "subsections" => subs } })
  end
end

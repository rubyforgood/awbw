class MonthlyReportFieldsChanges < ActiveRecord::Migration
  def change
    forms = FormBuilder.where('name LIKE ?', '%Monthly Report%')

    forms.each do |f|
      q = "Total # On-Going Participants"
      field = f.form_fields.find_by(question: q)
      field.update(instructional_hint: "On-Going means those who have done art with you at least once before.") unless field.nil?

      q = "Total # First-Time Participants"
      field = f.form_fields.find_by(question: q)
      field.update(instructional_hint: "First-Time means those who have never done art with you before, can only be first-time once.") unless field.nil?

      q = "Any Windows Program staff changes this month%"
      field = f.form_fields.where('question LIKE ?', q).first
      field.update(question: "List any Windows Program staff changes this month") unless field.nil?

      q = "How can we help you%"
      field = f.form_fields.where('question LIKE ?', q).first
      field.update(question: "Anything we can do to help you?") unless field.nil?
    end

    Sector.find_or_create_by(name: 'Other', published: true)
  end
end

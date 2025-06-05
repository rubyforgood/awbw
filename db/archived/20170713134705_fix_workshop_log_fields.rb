class FixWorkshopLogFields < ActiveRecord::Migration
  def change
    forms = FormBuilder.where('name LIKE ?', '%Workshop Log%')

    forms.each do |f|
      field = f.form_fields.where('question LIKE ?', "Age%").first
      field.update(question: "Age Groups",
        instructional_hint: "Select all that apply", ordering: 950) unless field.nil?
    end

  end
end

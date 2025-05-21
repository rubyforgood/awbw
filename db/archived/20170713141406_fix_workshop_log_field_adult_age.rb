class FixWorkshopLogFieldAdultAge < ActiveRecord::Migration
  def change
    forms = FormBuilder.where('name LIKE ?', '%Workshop Log%')

    forms.each do |f|
      field = f.form_fields.where('question LIKE ?', "Adult Age%").first
      field.update(question: "Adult Ages",
        instructional_hint: "Select all that apply", ordering: 950) unless field.nil?
    end

  end
end

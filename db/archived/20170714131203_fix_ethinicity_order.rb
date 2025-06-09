class FixEthinicityOrder < ActiveRecord::Migration
  def change
    forms = FormBuilder.where('name LIKE ?', '%Workshop Log%')

    forms.each do |f|
      field = f.form_fields.find_by(question: "Other").update(ordering: 570)
    end
  end
end

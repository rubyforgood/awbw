class UpdateEthnicityFiledsAsChilds < ActiveRecord::Migration
  def change
    forms = FormBuilder.where('name LIKE ?', '%Workshop Log%')


    forms.each do |f|
      parent_field = f.form_fields.find_by(question: "Ethnicity")

      [ "African American", "White", "Asian/Pacific Islander",
        "Native American", "Latino/a", "Other" ].each do |q|
        child = f.form_fields.find_by(question: q)
        parent_field.childs << child
      end
    end
  end
end

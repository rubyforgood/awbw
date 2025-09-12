class EthnicityNonAsRequired < ActiveRecord::Migration
  def change
    forms = FormBuilder.where('name LIKE ?', '%Workshop Log%')

    forms.each do |f|
      parent_field = f.form_fields.find_by(question: "Ethnicity")

      parent_field.childs.each{|c| c.update(is_required: false)}
    end
  end
end

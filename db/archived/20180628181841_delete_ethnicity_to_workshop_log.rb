class DeleteEthnicityToWorkshopLog < ActiveRecord::Migration
  def change
    forms = FormBuilder.where('name LIKE ?', '%Workshop Log%')
    forms.each do |f|
      field =  f.form_fields.find_by(question: "Ethnicity")
      field.update(status: 0) unless field.nil?
    end  
  end
end

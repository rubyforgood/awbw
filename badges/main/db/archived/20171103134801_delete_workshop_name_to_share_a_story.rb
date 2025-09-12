class DeleteWorkshopNameToShareAStory < ActiveRecord::Migration
  def change
    form = FormBuilder.find_by(name: "Share a Story")
    field = form.form_fields.find_by(question: "Workshop Name")
    field.update(status: 0) unless field.nil?
  end
end

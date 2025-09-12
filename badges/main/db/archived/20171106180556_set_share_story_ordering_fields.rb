class SetShareStoryOrderingFields < ActiveRecord::Migration
  def change
    form = FormBuilder.find_by(name: 'Share a Story')

    field = form.form_fields.find_by(question: "Participant's Name (optional)")
    field.update(ordering: 1000)

    field = form.form_fields.find_by(question: "Age(s) of Participant(s)")
    field.update(ordering: 950)

    field = form.form_fields.find_by(question: "Gender Identity/Identities of Participant(s)")
    field.update(ordering: 900)

    field = form.form_fields.find_by(question: "Service Population(s)")
    field.update(ordering: 850)

    field = form.form_fields.find_by(question: "Other Service Population")
    field.update(ordering: 800)

    field = form.form_fields.find_by(question: "Story/Quote")
    field.update(ordering: 750)
  end
end

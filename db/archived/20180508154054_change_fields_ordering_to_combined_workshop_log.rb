# coding: utf-8
class ChangeFieldsOrderingToCombinedWorkshopLog < ActiveRecord::Migration
  def change
    form = FormBuilder.where('name LIKE ?', '%Family Workshop Log%').first

    field = form.form_fields.find_by(question: "Number of Ongoing Adult Participants")
    field.update(ordering: 1000)

    field = form.form_fields.find_by(question: "Number of First-time Adult Participants")
    field.update(ordering: 950)

    field = form.form_fields.find_by(question: "Adult Ages")
    field.update(ordering: 900)


    field = form.form_fields.find_by(question: "Number of Ongoing Children Participants")
    field.update(ordering: 850)


    field = form.form_fields.find_by(question: "Number of First-time Children Participants")
    field.update(ordering: 800)


    field = form.form_fields.find_by(question: "Children's Ages")
    field.update(ordering: 750)

    field = form.form_fields.find_by(question: "Gender Identity")
    field.update(ordering: 700)


    field = form.form_fields.find_by(question: "Ethnicity")
    field.update(ordering: 650)


    field = form.form_fields.find_by(question: "Workshop Date")
    field.update(ordering: 600)


    field = form.form_fields.find_by(question: "Workshop Led")
    field.update(ordering: 500)

    field = form.form_fields.find_by(question: "Based on your overall observations of the participants' experiences with this workshop, please answer the following")
    field.update(ordering: 450)

    field = form.form_fields.find_by(question: "The workshop helped family members to open up about the difficult things they were experiencing at home")
    field.update(ordering: 445)

    field = form.form_fields.where("question like '%The workshop helped families deal constructively with feelings (handling anger and pain, finding pleasure and relaxation, etc.)'").first
    field.update(ordering: 440)

    field = form.form_fields.find_by(question: "The workshop helped the families talk about something they had never talked about")
    field.update(ordering: 435)

    field = form.form_fields.find_by(question: "The workshop was useful in helping these families take steps to break free from the effects of violence and trauma")
    field.update(ordering: 430)

    field = form.form_fields.find_by(question: "The workshop positively impacted family members’ relationship with each other (e.g. helped them build more effective communication, feel closer and more connected, create a new sense of family togetherness)")
    field.update(ordering: 425)

    field = form.form_fields.find_by(question: "The workshop helped the family members to reconnect with each other after the trauma they experienced and begin to build a new sense of family together")
    field.update(ordering: 420)

    field = form.form_fields.find_by(question: "Please share any highlights/successes")
    field.update(ordering: 400)

    field = form.form_fields.find_by(question: "Please share any challenges/difficulties")
    field.update(ordering: 350)
  end
end

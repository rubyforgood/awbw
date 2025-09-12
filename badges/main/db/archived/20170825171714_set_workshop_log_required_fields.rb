# coding: utf-8
class SetWorkshopLogRequiredFields < ActiveRecord::Migration
    def change
      questions = ["Total # On-going Participants",
                   "Total # First-Time Participants",
                   "Age Groups",
                   "Gender Identity",
                   "The workshop helped the participants to release emotions",
                   "The workshop helped the participants communicate openly",
                   "For ongoing participants, I see the art workshops increase resilience over time",
                   "The workshop helped participants develop a stronger sense of where they want to go",
                   "The workshop helped participants to cope with difficult feelings",

                   "The workshop helped the children to release emotions",
                   "The workshop helped the children to demonstrate self-confidence",
                   "The workshop helped the children/youth identify and name feelings",
                   "The workshop helped the children to communicate in a non-violent way",
                   "The workshop helped the children handle anger in a positive way",
                   "For ongoing participants, I see the art workshops increase resilience over time",

                   "Number of Ongoing Adult Participants",
                   "Number of First-time Adult Participants",
                   "Number of Ongoing Children Participants",
                   "Number of First-time Children Participants",
                   "Children's Ages", "Adult Ages",

                   "The workshop helped family members to open up about the difficult things they were experiencing at home",
                   "The workshop helped the families talk about something they had never talked about",
                   "The workshop was useful in helping these families take steps to break free from the effects of violence and trauma",
                   "The workshop positively impacted family members’ relationship with each other (e.g. helped them build more effective communication, feel closer and more connected, create a new sense of family togetherness)",
                   "The workshop helped the family members to reconnect with each other after the trauma they experienced and begin to build a new sense of family together"
                  ]

    forms = FormBuilder.where('name LIKE ?', '%Workshop Log%')

    forms.each do |form|
      questions.each do |q|
        field = form.form_fields.where('question LIKE ?', q).first
        field.update(is_required: true) unless field.nil?
      end
    end
  end
end

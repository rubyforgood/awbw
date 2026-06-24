module Events
  class FormSubmissionsController < ApplicationController
    before_action :set_event
    before_action :set_person

    def show
      authorize! @event

      @person = @person.decorate
      @form_submissions = @event.form_submissions
        .where(person: @person)
        .includes(form: :form_fields, form_answers: :form_field)
        .order(:created_at)
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_person
      @person = Person.find(params[:person_id])
    end
  end
end

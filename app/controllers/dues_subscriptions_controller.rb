class DuesSubscriptionsController < ApplicationController
  before_action :set_person

  def index
    authorize!
    @dues_subscriptions = @person.dues_subscriptions
      .includes(:dues_registrations)
      .order(created_at: :desc)
      .decorate
  end

  private

  def set_person
    @person = Person.find(params[:person_id])
  end
end

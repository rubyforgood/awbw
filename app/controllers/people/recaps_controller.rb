module People
  class RecapsController < ApplicationController
    before_action :set_person

    def show
      authorize! @person, to: :recap?

      respond_to do |format|
        format.turbo_stream
        format.html
      end
    end

    private

    def set_person
      @person = Person.find(params[:person_id])
    end
  end
end

# frozen_string_literal: true

class Admins::BaseController < ApplicationController
  before_action :authenticate_admin!
  def show
    redirect_to(rails_admin_path)
  end
end

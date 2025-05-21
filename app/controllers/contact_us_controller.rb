class ContactUsController < ApplicationController

  def index
  end

  def create
    ContactUsMailer.hello(params[:contact_us]).deliver_now
    flash[:alert] = "Your message was sent!"
    redirect_to '/'
  end
end

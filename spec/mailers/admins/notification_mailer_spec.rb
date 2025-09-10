# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Admins::NotificationMailer) do
  describe "#email" do
    it "renders successfully" do
      # Not sure if this mailer is actually never used, causing a bunch of errors, or the inky
      # extension is somehow working.
      pending "The template for this mailer has an extension of inky"
      raise
    end
  end
end

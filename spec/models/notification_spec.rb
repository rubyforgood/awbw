# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Notification) do
  describe "associations" do
    it { is_expected.to(belong_to(:noticeable)) }
  end

  describe "enums" do
    it { is_expected.to(define_enum_for(:notification_type).with_values([:created, :updated])) }
  end
end

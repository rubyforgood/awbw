require "rails_helper"

RSpec.describe FmPhoneNumberDecorator do
  it "shows the number with its note" do
    phone = FmPhoneNumber.new(data: { "PhoneType" => "Work", "PhoneNumber" => "(213) 555-0101", "Note" => "ext 4" }).decorate

    expect([ phone.kind, phone.summary ]).to eq([ "Work", "(213) 555-0101 · ext 4" ])
  end
end

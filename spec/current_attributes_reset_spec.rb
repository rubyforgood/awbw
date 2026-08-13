require "rails_helper"

# Regression guard for test-order pollution via ActiveSupport::CurrentAttributes.
# The executor only auto-resets Current around real requests/jobs; a spec that
# sets Current in the test thread (controller/view/service specs) has nothing to
# clear it, so a stale value leaks into later examples and silently changes
# model behavior that branches on Current (Organization affiliation-lock
# validation, AhoyTrackable lifecycle tracking). rails_helper resets Current
# after every example — this proves it. order: :defined pins the two examples so
# the second reliably follows the first regardless of the suite seed.
RSpec.describe "Current attributes reset between examples", order: :defined do
  it "leaves Current set within an example" do
    Current.user = User.new
    Current.source = "leak_probe"

    expect(Current.source).to eq "leak_probe"
  end

  it "starts the next example with a clean Current" do
    expect(Current.user).to be_nil
    expect(Current.source).to be_nil
  end
end

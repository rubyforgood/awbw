require "rails_helper"

RSpec.describe "Honeybadger context", type: :request do
  before { allow(Honeybadger).to receive(:context) }

  it "records the signed-in user so faults name who hit them" do
    user = create(:user)

    sign_in user
    get root_path

    expect(Honeybadger).to have_received(:context)
      .with(hash_including(user_id: user.id, user_email: user.email))
  end

  it "does not set user context for anonymous visitors" do
    get root_path

    expect(Honeybadger).not_to have_received(:context).with(hash_including(:user_id))
  end
end

require "rails_helper"

RSpec.describe TitleDisplayHelper, type: :helper do
  before do
    allow(helper).to receive(:controller_name).and_return("video_recordings")
    allow(helper).to receive(:controller_path).and_return("video_recordings")
    allow(helper).to receive(:user_signed_in?).and_return(false)
  end

  describe "#title_with_badges" do
    context "when record is instructional" do
      let(:record) { build(:video_recording, title: "Test Video", is_instructional: true) }

      it "includes the Instructional badge" do
        result = helper.title_with_badges(record)
        expect(result).to include("Instructional")
        expect(result).to include("fa-graduation-cap")
      end
    end

    context "when record is not instructional" do
      let(:record) { build(:video_recording, title: "Test Video", is_instructional: false) }

      it "does not include the Instructional badge" do
        result = helper.title_with_badges(record)
        expect(result).not_to include("Instructional")
      end
    end
  end
end

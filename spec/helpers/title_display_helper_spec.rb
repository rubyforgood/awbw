require "rails_helper"

RSpec.describe TitleDisplayHelper, type: :helper do
  before do
    allow(helper).to receive(:controller_name).and_return("video_recordings")
    allow(helper).to receive(:controller_path).and_return("video_recordings")
    allow(helper).to receive(:user_signed_in?).and_return(false)
    allow(helper).to receive(:current_user).and_return(nil)
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

    context "when record is hidden from search" do
      before do
        allow(helper).to receive(:controller_name).and_return("resources")
        allow(helper).to receive(:controller_path).and_return("resources")
        allow(helper).to receive(:current_user).and_return(current_user)
      end

      let(:record) { build(:resource, title: "Hidden Resource", hidden_from_search: true) }

      context "when viewed by an admin" do
        let(:current_user) { build(:user, super_user: true) }

        it "includes the Hidden badge" do
          result = helper.title_with_badges(record)
          expect(result).to include("Hidden from search")
          expect(result).to include("fa-filter-circle-xmark")
        end
      end

      context "when viewed by a non-admin user" do
        let(:current_user) { build(:user, super_user: false) }

        it "omits the Hidden badge" do
          result = helper.title_with_badges(record)
          expect(result).not_to include("fa-filter-circle-xmark")
        end
      end

      context "when viewed by a guest" do
        let(:current_user) { nil }

        it "omits the Hidden badge" do
          result = helper.title_with_badges(record)
          expect(result).not_to include("fa-filter-circle-xmark")
        end
      end
    end
  end
end

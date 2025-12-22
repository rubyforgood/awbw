require "rails_helper"

RSpec.describe Tag, type: :model do
	describe "TAGGABLE_META" do
		it "defines a metadata hash with all required keys" do
			Tag::TAGGABLE_META.each do |key, meta|
				expect(meta).to include(:icon, :path, :klass)

				expect(meta[:icon]).to be_a(String)
				expect(meta[:path]).to respond_to(:call)
				expect(meta[:klass]).to be_a(Class)
			end
		end

		it "uses symbol keys" do
			expect(Tag::TAGGABLE_META.keys).to all(be_a(Symbol))
		end
	end

	describe ".dashboard_card_for" do
		let(:key) { :workshops }
		let(:card) { Tag.dashboard_card_for(key) }

		it "returns a hash with the expected structure" do
			expect(card).to include(
												:title,
												:path,
												:icon,
												:bg_color,
												:hover_bg_color,
												:text_color
											)
		end

		it "uses humanized title" do
			expect(card[:title]).to eq("Workshops")
		end

		it "returns the correct icon" do
			expect(card[:icon]).to eq(Tag::TAGGABLE_META[:workshops][:icon])
		end

		it "calls the correct path helper" do
			expected_path = Rails.application.routes.url_helpers.workshops_path
			expect(card[:path]).to eq(expected_path)
		end

		it "generates the correct background color class" do
			expected_color = DomainTheme.bg_class_for(:workshops)
			expect(card[:bg_color]).to eq(expected_color)
		end

		it "generates the correct hover background color class" do
			expected_hover = DomainTheme.bg_class_for(:workshops, intensity: 100)
			expect(card[:hover_bg_color]).to eq(expected_hover)
		end

		it "sets a default text color" do
			expect(card[:text_color]).to eq("text-gray-800")
		end

		it "raises a KeyError for unknown keys" do
			expect { Tag.dashboard_card_for(:not_real) }.to raise_error(KeyError)
		end
	end
end

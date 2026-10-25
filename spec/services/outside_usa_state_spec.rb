require "rails_helper"

RSpec.describe OutsideUsaState do
  describe ".pick" do
    it "takes the typed state when one is filled in" do
      expect(described_class.pick("CA", " Ontario ")).to eq("Ontario")
    end

    it "falls back to the dropdown when nothing is typed" do
      expect(described_class.pick("CA", " ")).to eq("CA")
    end
  end

  describe ".form_field_answers" do
    def params_for(form_fields:, typed: nil)
      ActionController::Parameters.new(public_registration: { form_fields:, form_fields_outside_usa: typed }.compact)
    end

    it "lays each typed state over its dropdown answer and leaves the rest alone" do
      params = params_for(form_fields: { "1" => "", "2" => "Sam" }, typed: { "1" => "Ontario" })

      expect(described_class.form_field_answers(params, :public_registration)).to eq("1" => "Ontario", "2" => "Sam")
    end

    it "keeps the dropdown answer when the typed box is blank" do
      params = params_for(form_fields: { "1" => "CA" }, typed: { "1" => "" })

      expect(described_class.form_field_answers(params, :public_registration)).to eq("1" => "CA")
    end

    it "lays a typed state over a fanned-out answer for its resource" do
      params = params_for(form_fields: { "1" => { "7" => "", "8" => "NY" } }, typed: { "1" => { "7" => "Ontario", "8" => "" } })

      expect(described_class.form_field_answers(params, :public_registration)).to eq("1" => { "7" => "Ontario", "8" => "NY" })
    end

    context "with a country question paired to the state" do
      let(:form) { create(:form) }
      let(:state) { create(:form_field, form: form, field_identifier: "mailing_state") }
      let(:country) { create(:form_field, form: form, field_identifier: "mailing_country") }

      it "records the US for a blank country beside a US state" do
        params = params_for(form_fields: { state.id.to_s => "CA", country.id.to_s => "" })

        expect(described_class.form_field_answers(params, :public_registration)[country.id.to_s]).to eq("United States")
      end

      it "leaves a blank country alone beside a typed state" do
        params = params_for(form_fields: { state.id.to_s => "", country.id.to_s => "" }, typed: { state.id.to_s => "Ontario" })

        expect(described_class.form_field_answers(params, :public_registration)[country.id.to_s]).to eq("")
      end

      it "keeps a picked country" do
        params = params_for(form_fields: { state.id.to_s => "CA", country.id.to_s => "Mexico" })

        expect(described_class.form_field_answers(params, :public_registration)[country.id.to_s]).to eq("Mexico")
      end
    end

    it "returns the answers untouched when no state was typed" do
      params = params_for(form_fields: { "1" => "CA" })

      expect(described_class.form_field_answers(params, :public_registration)).to eq("1" => "CA")
    end
  end
end

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#dollars_from_cents" do
    it "drops the cents for whole-dollar amounts and adds thousands separators" do
      expect(helper.dollars_from_cents(150_000)).to eq("$1,500")
      expect(helper.dollars_from_cents(5_000)).to eq("$50")
      expect(helper.dollars_from_cents(1_234_500)).to eq("$12,345")
      expect(helper.dollars_from_cents(0)).to eq("$0")
    end

    it "keeps the cents for fractional amounts" do
      expect(helper.dollars_from_cents(75_050)).to eq("$750.50")
      expect(helper.dollars_from_cents(1_099)).to eq("$10.99")
      expect(helper.dollars_from_cents(1_234_556)).to eq("$12,345.56")
    end
  end

  describe "#staging_environment?" do
    context "when RAILS_ENV is staging" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("staging")
      end

      it "returns true" do
        expect(helper.staging_environment?).to be true
      end
    end

    context "when Rails.env is staging" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return(nil)
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("staging"))
      end

      it "returns true" do
        expect(helper.staging_environment?).to be true
      end
    end

    context "when environment is not staging" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("production")
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      end

      it "returns false" do
        expect(helper.staging_environment?).to be false
      end
    end
  end

  describe "#navbar_bg_class" do
    context "when in staging environment" do
      before do
        allow(helper).to receive(:staging_environment?).and_return(true)
      end

      it "returns bg-red-600" do
        expect(helper.navbar_bg_class).to eq("bg-red-600")
      end
    end

    context "when not in staging environment" do
      before do
        allow(helper).to receive(:staging_environment?).and_return(false)
      end

      it "returns bg-primary" do
        expect(helper.navbar_bg_class).to eq("bg-primary")
      end
    end
  end

  describe "#favicon_file" do
    context "when environment is production" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      end

      it "returns logo-circle.png" do
        expect(helper.favicon_file).to eq("logo-circle.png")
      end
    end

    context "when environment is staging" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("staging"))
      end

      it "returns favicon.png" do
        expect(helper.favicon_file).to eq("favicon.png")
      end
    end

    context "when environment is development" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      end

      it "returns theme_default.png" do
        expect(helper.favicon_file).to eq("theme_default.png")
      end
    end

    context "when environment is test" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))
      end

      it "returns theme_default.png" do
        expect(helper.favicon_file).to eq("theme_default.png")
      end
    end
  end

  describe "#form_label_html" do
    it "preserves allowed formatting and link tags" do
      input = %(Visit <a href="https://example.com">our site</a><br>line two <strong>bold</strong>)
      expect(helper.form_label_html(input)).to eq(input)
    end

    it "keeps heading tags" do
      expect(helper.form_label_html("<h2>Section</h2>")).to eq("<h2>Section</h2>")
    end

    it "keeps font size and color via inline style" do
      input = %(<span style="font-size:24px;color:#ff0000">big red</span>)
      result = helper.form_label_html(input)
      expect(result).to include("font-size:24px")
      expect(result).to include("color:#ff0000")
    end

    it "keeps font size and color via the font tag" do
      input = %(<font size="5" color="blue">styled</font>)
      expect(helper.form_label_html(input)).to eq(input)
    end

    it "scrubs dangerous css from the style attribute while keeping safe properties" do
      result = helper.form_label_html(%(<span style="color:red;background:url(javascript:alert(1))">x</span>))
      expect(result).to include("color:red")
      expect(result).not_to include("javascript")
    end

    it "strips disallowed tags but keeps their text" do
      expect(helper.form_label_html("<script>alert(1)</script>Hello")).to eq("alert(1)Hello")
    end

    it "removes dangerous link schemes" do
      result = helper.form_label_html(%(<a href="javascript:alert(1)">x</a>))
      expect(result).not_to include("javascript:")
    end

    it "returns an html_safe string" do
      expect(helper.form_label_html("<br>")).to be_html_safe
    end
  end
end

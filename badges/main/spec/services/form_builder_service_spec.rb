require "rails_helper"

RSpec.describe FormBuilderService do
  describe "#call" do
    it "creates a form with the given name" do
      form = described_class.new(name: "Test Form", sections: %i[person_identifier]).call
      expect(form.name).to eq("Test Form")
    end

    it "stores selected sections on the form" do
      form = described_class.new(name: "Test", sections: %i[person_identifier consent]).call
      expect(form.sections).to eq(%w[person_identifier consent])
    end

    it "sets role flag" do
      form = described_class.new(name: "Scholarship", sections: %i[scholarship], role: "scholarship").call
      expect(form.role).to eq "scholarship"
    end

    it "creates fields with sequential positions" do
      form = described_class.new(name: "Test", sections: %i[person_identifier consent]).call
      positions = form.form_fields.unscoped.where(form: form).order(:position).pluck(:position)
      expect(positions).to eq((1..positions.size).to_a)
    end

    context "person_identifier section" do
      let(:form) { described_class.new(name: "Test", sections: %i[person_identifier]).call }

      it "creates first_name, last_name, primary_email, and confirm_email fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("first_name", "last_name", "primary_email", "confirm_email")
      end

      it "defaults paired name fields to half width" do
        field = form.form_fields.find_by(field_identifier: "first_name")
        expect(field.width).to eq("half")
      end
    end

    context "default field widths" do
      let(:form) { described_class.new(name: "Test", sections: %i[person_contact_info]).call }

      it "lays city/state/zip out as thirds" do
        widths = form.form_fields.where(field_identifier: %w[mailing_city mailing_state mailing_zip]).pluck(:width)
        expect(widths).to all(eq("third"))
      end

      it "leaves unlisted fields at full width" do
        field = form.form_fields.find_by(field_identifier: "agency_website")
        expect(field.width).to eq("full")
      end
    end

    context "person_contact_info section" do
      let(:form) { described_class.new(name: "Test", sections: %i[person_contact_info]).call }

      it "creates contact info fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("nickname", "pronouns", "phone", "mailing_city", "agency_name")
      end

      it "offers the agency type as the four organization classifications" do
        field = form.form_fields.find_by(field_identifier: "agency_type")
        expect(field.answer_options.pluck(:name)).to contain_exactly(
          "501c3/nonprofit", "For-profit", "Government agency", "Other (please specify below)"
        )
      end
    end

    context "scholarship section" do
      let(:form) { described_class.new(name: "Test", sections: %i[scholarship]).call }

      it "creates scholarship fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("scholarship_eligibility", "impact_description", "implementation_plan")
      end
    end

    context "consent section" do
      let(:form) { described_class.new(name: "Test", sections: %i[consent]).call }

      it "creates communication_consent field" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("communication_consent")
      end
    end

    context "payment section" do
      let(:form) { described_class.new(name: "Test", sections: %i[payment]).call }

      it "creates payment fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("payment_method")
      end
    end

    context "bulk_payment section" do
      let(:form) { described_class.new(name: "Test", sections: %i[bulk_payment], role: "bulk_payment").call }

      it "creates payer fields including an optional phone field" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include(
          "payer_first_name", "payer_last_name", "payer_email", "payer_phone", "payer_organization"
        )
      end

      it "makes the phone and organization fields optional" do
        phone = form.form_fields.find_by(field_identifier: "payer_phone")
        organization = form.form_fields.find_by(field_identifier: "payer_organization")
        expect(phone.required).to be(false)
        expect(organization.required).to be(false)
      end

      it "lays payer name, email, and phone fields out as halves" do
        widths = form.form_fields.where(
          field_identifier: %w[payer_first_name payer_last_name payer_email payer_phone]
        ).pluck(:width)
        expect(widths).to all(eq("half"))
      end
    end

    context "marketing section" do
      let(:form) { described_class.new(name: "Test", sections: %i[marketing]).call }

      it "creates marketing fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("referral_source", "training_motivation", "interested_in_more")
      end
    end

    context "post_event_feedback section" do
      let(:form) { described_class.new(name: "Test", sections: %i[post_event_feedback]).call }

      it "creates post-event feedback fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("event_rating", "most_valuable", "improvement_suggestions")
      end
    end

    context "with multiple sections (short event registration)" do
      let(:form) do
        described_class.new(
          name: "Short Event Registration",
          sections: %i[person_identifier consent marketing scholarship]
        ).call
      end

      it "creates fields from all selected sections" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("first_name", "communication_consent", "referral_source", "scholarship_eligibility")
      end

      it "does not include fields from unselected sections" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).not_to include("nickname", "phone", "payment_method")
      end
    end

    context "with multiple sections (extended event registration)" do
      let(:form) do
        described_class.new(
          name: "Extended Event Registration",
          sections: %i[person_identifier person_contact_info person_background professional_info marketing scholarship payment consent]
        ).call
      end

      it "creates fields from all sections" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include(
          "first_name", "nickname", "racial_ethnic_identity",
          "primary_service_area", "referral_source",
          "scholarship_eligibility", "payment_method", "communication_consent"
        )
      end
    end
  end

  describe ".update_sections!" do
    it "adds new sections and their fields" do
      form = described_class.new(name: "Test", sections: %i[person_identifier]).call
      initial_count = form.form_fields.count

      described_class.update_sections!(form, %i[person_identifier consent])

      form.reload
      expect(form.sections).to eq(%w[person_identifier consent])
      expect(form.form_fields.count).to be > initial_count
      expect(form.form_fields.pluck(:field_identifier).compact).to include("communication_consent")
    end

    it "removes unchecked sections and their fields" do
      form = described_class.new(name: "Test", sections: %i[person_identifier consent]).call
      expect(form.form_fields.where(section: "consent").count).to be > 0

      described_class.update_sections!(form, %i[person_identifier])

      form.reload
      expect(form.sections).to eq(%w[person_identifier])
      expect(form.form_fields.where(section: "consent")).to be_empty
    end

    it "removes section headers when a section is removed" do
      form = described_class.new(name: "Test", sections: %i[person_identifier scholarship]).call
      expect(form.form_fields.where(answer_type: :group_header, name: "Scholarship Application")).to exist

      described_class.update_sections!(form, %i[person_identifier])

      form.reload
      expect(form.form_fields.where(answer_type: :group_header, name: "Scholarship Application")).not_to exist
    end

    it "preserves existing fields when sections are unchanged" do
      form = described_class.new(name: "Test", sections: %i[person_identifier consent]).call
      original_ids = form.form_fields.pluck(:id).sort

      described_class.update_sections!(form, %i[person_identifier consent])

      form.reload
      expect(form.form_fields.pluck(:id).sort).to eq(original_ids)
    end

    it "appends new fields after existing ones" do
      form = described_class.new(name: "Test", sections: %i[person_identifier]).call
      max_before = form.form_fields.maximum(:position)

      described_class.update_sections!(form, %i[person_identifier consent])

      new_fields = form.form_fields.where(section: "consent")
      expect(new_fields.minimum(:position)).to be > max_before
    end

    it "inserts a newly added section in page order rather than at the end" do
      form = described_class.new(name: "Test", sections: %i[person_identifier payment]).call

      described_class.update_sections!(form, %i[person_identifier person_contact_info payment])

      form.reload
      ordered_sections = form.form_fields.reorder(:position).pluck(:section).uniq
      expect(ordered_sections.index("person_contact_info")).to be < ordered_sections.index("payment")
    end

    it "leaves positions sequential after inserting a section in the middle" do
      form = described_class.new(name: "Test", sections: %i[person_identifier payment]).call

      described_class.update_sections!(form, %i[person_identifier person_contact_info payment])

      form.reload
      positions = form.form_fields.reorder(:position).pluck(:position)
      expect(positions).to eq((1..positions.size).to_a)
    end

    it "removes a custom section and its questions by header id" do
      form = described_class.new(name: "Test", sections: %i[person_identifier]).call
      header = form.form_fields.create!(name: "Custom", answer_type: :group_header,
                                        status: :active, position: 100, required: false)
      question = form.form_fields.create!(name: "Q1", answer_type: :free_form_input_one_line,
                                          status: :active, position: 101, required: false)
      next_section = form.form_fields.create!(name: "Background Information", answer_type: :group_header,
                                              status: :active, position: 102, section: "background", required: false)

      described_class.update_sections!(form, %i[person_identifier], remove_custom_section_ids: [ header.id ])

      expect(FormField.where(id: [ header.id, question.id ])).to be_empty
      expect(FormField.where(id: next_section.id)).to exist
    end

    it "leaves custom sections untouched when none are unchecked" do
      form = described_class.new(name: "Test", sections: %i[person_identifier]).call
      header = form.form_fields.create!(name: "Custom", answer_type: :group_header,
                                        status: :active, position: 100, required: false)

      described_class.update_sections!(form, %i[person_identifier])

      expect(FormField.where(id: header.id)).to exist
    end
  end

  describe ".editable_sections" do
    let(:form) { described_class.new(name: "Test", sections: %i[person_identifier consent]).call }

    def add_field(name, answer_type, position, section: nil)
      form.form_fields.create!(name: name, answer_type: answer_type, status: :active,
                               position: position, required: false, section: section)
    end

    it "marks built-in sections on the form as included and others as not" do
      entries = described_class.editable_sections(form)
      included = entries.select { |e| e[:kind] == :builtin && e[:included] }.map { |e| e[:key] }
      excluded = entries.select { |e| e[:kind] == :builtin && !e[:included] }.map { |e| e[:key] }

      expect(included).to include(:person_identifier, :consent)
      expect(excluded).to include(:marketing, :payment)
    end

    it "includes a custom section with the questions that follow it" do
      add_field("My Custom Section", :group_header, 100)
      first = add_field("Favorite color", :free_form_input_one_line, 101)
      second = add_field("Why?", :free_form_input_paragraph, 102)

      custom = described_class.editable_sections(form).find { |e| e[:kind] == :custom }

      expect(custom[:label]).to eq("My Custom Section")
      expect(custom[:questions]).to eq([ first, second ])
    end

    it "stops a custom section's questions at the next header" do
      add_field("My Custom Section", :group_header, 100)
      question = add_field("Favorite color", :free_form_input_one_line, 101)
      add_field("Background Information", :group_header, 102, section: "background")

      custom = described_class.editable_sections(form).find { |e| e[:kind] == :custom }

      expect(custom[:questions]).to eq([ question ])
    end

    it "orders a custom section by where it sits on the form" do
      # person_identifier (pos 1-4), consent header + field, then the custom
      # section is dropped between them by giving it an in-between position.
      consent_position = form.form_fields.find_by(section: "consent", answer_type: :group_header).position
      add_field("My Custom Section", :group_header, consent_position - 1)

      kinds = described_class.editable_sections(form)
        .select { |e| (e[:kind] == :builtin && e[:included]) || e[:kind] == :custom }
        .map { |e| e[:kind] == :custom ? :custom : e[:key] }

      expect(kinds).to eq([ :person_identifier, :custom, :consent ])
    end

    it "has no custom entries when the form has none" do
      expect(described_class.editable_sections(form).map { |e| e[:kind] }).to all(eq(:builtin))
    end

    it "surfaces a renamed built-in section header" do
      form.form_fields.find_by(section: "consent", answer_type: :group_header).update!(name: "Agreement")

      consent = described_class.editable_sections(form).find { |e| e[:key] == :consent }
      expect(consent[:renamed_header]).to eq("Agreement")
    end

    it "does not flag a built-in section header left at its default name" do
      consent = described_class.editable_sections(form).find { |e| e[:key] == :consent }
      expect(consent[:renamed_header]).to be_nil
    end

    it "tolerates fields with a nil position without raising" do
      form.form_fields.create!(name: "My Custom Section", answer_type: :group_header,
                               status: :active, position: nil, required: false)

      expect { described_class.editable_sections(form) }.not_to raise_error
    end
  end
end

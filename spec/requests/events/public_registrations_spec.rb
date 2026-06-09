require "rails_helper"

RSpec.describe "Events::PublicRegistrations", type: :request do
  # A guest registering on a free event so we exercise the bare create path
  # without payment or auth.
  let(:event) { create(:event, cost_cents: 0) }
  let(:form) { create(:form) }
  let!(:essay_field) do
    create(:form_field, form: form, answer_type: :free_form_input_paragraph,
           name: "Tell us why you'd like to attend", required: true, min_words: 5)
  end

  before { EventForm.create!(event: event, form: form, role: "registration") }

  def post_registration(answer)
    post event_public_registration_path(event),
         params: { public_registration: { form_fields: { essay_field.id.to_s => answer } } }
  end

  describe "POST create with a minimum word count" do
    it "rejects an answer with too few words" do
      expect {
        post_registration("not quite enough")
      }.not_to change(EventRegistration, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be at least 5 words")
    end

    it "does not flag an answer that meets the minimum" do
      post_registration("this answer has plenty of words")

      expect(response.body).not_to include("must be at least 5 words")
    end
  end

  describe "POST create with a maximum character count" do
    let!(:bio_field) do
      create(:form_field, form: form, answer_type: :free_form_input_one_line,
             name: "Nickname", required: false, max_characters: 10)
    end

    def post_bio(answer)
      post event_public_registration_path(event),
           params: { public_registration: { form_fields: {
             essay_field.id.to_s => "this answer has plenty of words",
             bio_field.id.to_s => answer
           } } }
    end

    it "rejects an answer that is too long" do
      expect {
        post_bio("a" * 11)
      }.not_to change(EventRegistration, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be 10 characters or fewer")
    end

    it "does not flag an answer within the maximum" do
      post_bio("short")

      expect(response.body).not_to include("must be 10 characters or fewer")
    end
  end

  describe "GET new" do
    it "shows the minimum word hint below the field" do
      get new_event_public_registration_path(event)

      expect(response.body).to include("Minimum of 5 words.")
    end

    it "shows the maximum character hint below the field" do
      create(:form_field, form: form, answer_type: :free_form_input_paragraph,
             name: "Bio", required: false, max_characters: 250)

      get new_event_public_registration_path(event)

      expect(response.body).to include("Maximum of 250 characters.")
    end
  end
end

require "rails_helper"

RSpec.describe "Comments and communications", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, email: "primary@example.com") }

  describe "GET /comments_and_communications?person_id=" do
    before { sign_in admin }

    it "renders the page shell with the filter bar" do
      get comments_and_communications_path(person_id: person.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Comments &amp; communications")
      # The shared filters, each answered on both models' own columns.
      expect(response.body).to include("Subject or topic")
      expect(response.body).to include("From or author")
      expect(response.body).to include("Attached to")
      expect(response.body).to include("Follow-up")
    end

    it "renders comments and communications together in the results frame" do
      create(:comment, commentable: person, body: "Internal staff note", created_by: admin)
      create(:notification, recipient_email: "primary@example.com", email_subject: "Welcome aboard",
                            kind: "manual_log", channel: "email", recipient_role: "person", notification_type: 0)

      get comments_and_communications_path(person_id: person.id), headers: { "Turbo-Frame" => "comments_and_communications_results" }

      expect(response.body).to include("Internal staff note")
      expect(response.body).to include("Welcome aboard")
    end

    it "starts the comment body flush under its topic instead of truncating it" do
      create(:comment, commentable: person, topic: "Topic line", body: "A note", created_by: admin)

      get comments_and_communications_path(person_id: person.id), headers: { "Turbo-Frame" => "comments_and_communications_results" }

      body = Nokogiri::HTML(response.body).css("div").find { |div| div.text.strip == "A note" }
      expect(body["class"]).not_to include("truncate")
      # Topic and body share one flex column, so both start at the same left edge.
      expect(body.parent["class"]).to include("flex-1")
      expect(body.parent.text).to include("Topic line")
    end

    it "puts the attached record's chip on the headline row, above the body" do
      registration = create(:event_registration, registrant: person)
      create(:comment, commentable: registration, body: "On the registration", created_by: admin)

      get comments_and_communications_path(person_id: person.id), headers: { "Turbo-Frame" => "comments_and_communications_results" }

      doc = Nokogiri::HTML(response.body)
      chip = doc.at_css("a[href='#{edit_event_registration_path(registration)}']")
      body = doc.css("div").find { |div| div.text.strip == "On the registration" }
      expect(chip).to be_present
      # The chip leads the headline row; the body follows it as a full-width line.
      expect(chip <=> body).to eq(-1)
    end

    it "links a communication's chip to its noticeable and names the record" do
      registration = create(:event_registration, registrant: person)
      notification = create(:notification, noticeable: registration, recipient_email: "primary@example.com",
                                           email_subject: "About the registration", kind: "manual_log",
                                           channel: "email", recipient_role: "person", notification_type: 0)

      get comments_and_communications_path(person_id: person.id), headers: { "Turbo-Frame" => "comments_and_communications_results" }

      doc = Nokogiri::HTML(response.body)
      chip = doc.at_css("a[href='#{edit_event_registration_path(registration)}']")
      expect(chip).to be_present
      # The record's own label, not a bare "##{registration.id}" fallback.
      expect(chip.text.strip).to start_with("Registration ·")
      # The subject still reaches the communication itself.
      expect(doc.at_css("a[href='#{notification_path(notification)}']")&.text.to_s).to include("About the registration")
    end

    it "offers composers that file a note or a communication against a chosen record" do
      registration = create(:event_registration, registrant: person)

      get comments_and_communications_path(person_id: person.id)

      doc = Nokogiri::HTML(response.body)
      # Both composers list the person's records; each submits a signed GlobalID.
      expect(doc.at_css("select#commentable_sgid")).to be_present
      expect(doc.at_css("select#noticeable_sgid")).to be_present
      labels = doc.css("select#noticeable_sgid option").map(&:text)
      expect(labels).to include("Profile")
      expect(labels.any? { |label| label.start_with?("Registration ·") }).to be(true)
      expect(registration).to be_persisted
    end

    it "files a note against the picked record and returns to the person's feed" do
      registration = create(:event_registration, registrant: person)

      expect {
        post person_comments_path(person), params: {
          for_person_id: person.id,
          commentable_sgid: registration.to_sgid.to_s,
          comment: { body: "Called the family" }
        }
      }.to change(Comment, :count).by(1)

      logged = Comment.order(:created_at).last
      expect(logged.commentable).to eq(registration)
      expect(response).to redirect_to(comments_and_communications_path(person_id: person.id))
    end

    it "logs a communication against the picked record and returns to the feed" do
      registration = create(:event_registration, registrant: person)

      expect {
        post notifications_path, params: {
          person_id: person.id,
          for_person_id: person.id,
          noticeable_sgid: registration.to_sgid.to_s,
          notification: { channel: "phone", email_subject: "Called about the registration" }
        }
      }.to change(Notification, :count).by(1)

      logged = Notification.order(:created_at).last
      expect(logged.noticeable).to eq(registration)
      expect(logged.recipient_email).to eq(person.communications_email)
      expect(response).to redirect_to(comments_and_communications_path(person_id: person.id))
    end

    it "denies a non-admin" do
      sign_in create(:user)

      get comments_and_communications_path(person_id: person.id)

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "GET /comments_and_communications (unified, everyone)" do
    before { sign_in admin }

    it "spans comments and communications across every person" do
      other = create(:person, email: "other@example.com")
      create(:comment, commentable: person, body: "Note about primary", created_by: admin)
      create(:comment, commentable: other, body: "Note about other", created_by: admin)
      create(:notification, recipient_email: "other@example.com", email_subject: "Hello other",
                            kind: "manual_log", channel: "email", recipient_role: "person", notification_type: 0)

      get comments_and_communications_path

      expect(response).to have_http_status(:ok)
      # The composers load per-person into a frame, so the index itself carries a
      # person picker and the empty frame, not the composers inline.
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("[data-controller='panel-toggle']")).to be_nil
      expect(doc.at_css("turbo-frame#cc_composers")).to be_present
      expect(doc.at_css("select#person_id")).to be_present

      get comments_and_communications_path, headers: { "Turbo-Frame" => "comments_and_communications_results" }

      expect(response.body).to include("comments_and_communications_results")
      expect(response.body).to include("Note about primary")
      expect(response.body).to include("Note about other")
      expect(response.body).to include("Hello other")
    end

    it "loads a picked person's composers into the frame with their filing targets" do
      registration = create(:event_registration, registrant: person)

      get composers_comments_and_communications_path(person_id: person.id),
          headers: { "Turbo-Frame" => "cc_composers" }

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("turbo-frame#cc_composers")).to be_present
      expect(doc.at_css("select#commentable_sgid")).to be_present
      expect(doc.at_css("select#noticeable_sgid")).to be_present
      labels = doc.css("select#noticeable_sgid option").map(&:text)
      expect(labels).to include("Profile")
      expect(labels.any? { |label| label.start_with?("Registration ·") }).to be(true)
      expect(registration).to be_persisted
    end

    it "prompts to pick a person when the composers frame loads with none" do
      get composers_comments_and_communications_path, headers: { "Turbo-Frame" => "cc_composers" }

      expect(response.body).to include("Pick a person")
      expect(Nokogiri::HTML(response.body).at_css("select#commentable_sgid")).to be_nil
    end

    it "denies a non-admin" do
      sign_in create(:user)

      get comments_and_communications_path

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "inline edit from the feed" do
    before { sign_in admin }

    it "shows an Edit control for a comment and saves changes in place" do
      comment = create(:comment, commentable: person, body: "Original note", created_by: admin)

      get comments_and_communications_path(person_id: person.id), headers: { "Turbo-Frame" => "comments_and_communications_results" }
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("##{ActionView::RecordIdentifier.dom_id(comment)} button")&.text).to include("Edit")

      patch comment_path(comment), params: { combined: 1, comment: { body: "Updated note" } },
                                    headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Updated note")
      expect(comment.reload.body).to eq("Updated note")
    end

    it "shows an Edit control for a comment whose commentable has no nested comments route (e.g. an affiliation)" do
      affiliation = create(:affiliation, person: person)
      comment = create(:comment, commentable: affiliation, body: "On the affiliation", created_by: admin)

      get comments_and_communications_path(person_id: person.id), headers: { "Turbo-Frame" => "comments_and_communications_results" }
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("##{ActionView::RecordIdentifier.dom_id(comment)} button")&.text).to include("Edit")

      patch comment_path(comment), params: { combined: 1, comment: { body: "Updated affiliation note" } },
                                    headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(comment.reload.body).to eq("Updated affiliation note")
    end

    it "shows an Edit control for a communication and saves changes in place" do
      notification = create(:notification, noticeable: person, recipient_email: "primary@example.com",
                                           email_subject: "Original subject", kind: "manual_log",
                                           channel: "email", recipient_role: "person", notification_type: 0)

      get comments_and_communications_path(person_id: person.id), headers: { "Turbo-Frame" => "comments_and_communications_results" }
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("##{ActionView::RecordIdentifier.dom_id(notification)} button")&.text).to include("Edit")

      patch notification_path(notification), params: { combined: 1, notification: { email_subject: "Updated subject" } },
                                              headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Updated subject")
      expect(notification.reload.email_subject).to eq("Updated subject")
    end

    it "hides the Edit control for an automated email" do
      autoemail = create(:notification, noticeable: person, recipient_email: "primary@example.com",
                                        email_subject: "Welcome!", notification_type: 0)
      expect(autoemail.manual_log?).to be(false)

      get comments_and_communications_path(person_id: person.id), headers: { "Turbo-Frame" => "comments_and_communications_results" }

      doc = Nokogiri::HTML(response.body)
      row = doc.at_css("##{ActionView::RecordIdentifier.dom_id(autoemail)}")
      expect(row.text).to include("Welcome!")
      expect(row.at_css("button")).to be_nil
    end
  end

  describe "the combined section's link to the feed" do
    before { sign_in admin }

    it "offers one 'All comments & communications' link carrying the origin record" do
      get edit_person_path(person)

      expect(response.body).to include("All comments &amp; communications")
      expect(response.body).to include(CGI.escapeHTML(
        comments_and_communications_path(person_id: person.id, return_to_type: "Person", return_to_id: person.id)
      ))
      expect(response.body).not_to include(">All comments\n")
    end

    it "links to the registrant's feed from an event registration" do
      registration = create(:event_registration, registrant: person)

      get edit_event_registration_path(registration)

      expect(response.body).to include(CGI.escapeHTML(
        comments_and_communications_path(person_id: person.id, return_to_type: "EventRegistration", return_to_id: registration.id)
      ))
    end
  end
end

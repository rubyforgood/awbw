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

    it "groups entries by subject in the results frame when the toggle is on" do
      create(:comment, commentable: person, topic: "Scholarship", body: "A note about it", created_by: admin)
      create(:notification, recipient_email: "primary@example.com", email_subject: "Scholarship",
                            kind: "manual_log", channel: "email", recipient_role: "person", notification_type: 0)
      # An unattached communication exercises the nil-noticeable path under grouping.
      create(:notification, recipient_email: "primary@example.com", email_subject: "Loose end",
                            kind: "manual_log", channel: "email", recipient_role: "person", notification_type: 0)

      get comments_and_communications_path(person_id: person.id, group_by_subject: "1"),
          headers: { "Turbo-Frame" => "comments_and_communications_results" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("comments_and_communications_results")
      # The comment and communication that share "Scholarship" sit under one group header.
      expect(response.body).to include("2 items")
      expect(response.body).to include("A note about it")
      expect(response.body).to include("Loose end")
    end

    it "orders grouped rows newest-first, and groups by their newest row" do
      create(:comment, commentable: person, topic: "Profile", body: "Middle in profile", created_by: admin, created_at: Time.zone.parse("2026-08-07 13:35"))
      create(:comment, commentable: person, topic: "Profile", body: "Oldest in profile", created_by: admin, created_at: Time.zone.parse("2021-09-19 17:00"))
      create(:notification, recipient_email: "primary@example.com", email_subject: "Profile", email_body_text: "Newest in profile",
                            kind: "manual_log", channel: "email", recipient_role: "person", notification_type: 0, created_at: Time.zone.parse("2026-09-20 19:13"))
      create(:notification, recipient_email: "primary@example.com", email_subject: "Alpha", email_body_text: "Newest overall",
                            kind: "manual_log", channel: "email", recipient_role: "person", notification_type: 0, created_at: Time.zone.parse("2026-09-25 09:00"))

      get comments_and_communications_path(person_id: person.id, group_by_subject: "1"),
          headers: { "Turbo-Frame" => "comments_and_communications_results" }

      body = response.body
      # Groups by newest row: Alpha (9/25) leads Profile (9/20).
      expect(body.index("Alpha")).to be < body.index("Profile")
      # Within Profile: newest, middle, oldest, top to bottom.
      newest = body.index("Newest in profile")
      middle = body.index("Middle in profile")
      oldest = body.index("Oldest in profile")
      expect(newest).to be < middle
      expect(middle).to be < oldest
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

    it "offers the person's form submissions, affiliations, and staff tags as targets" do
      create(:form_submission, person: person)
      create(:affiliation, person: person, organization: create(:organization, name: "Sunrise Center"))
      create(:staff_tagging, staff_taggable: person, staff_tag: create(:staff_tag, name: "VIP"))

      get comments_and_communications_path(person_id: person.id)

      labels = Nokogiri::HTML(response.body).css("select#noticeable_sgid option").map(&:text)
      expect(labels.any? { |label| label.start_with?("Form ·") }).to be(true)
      expect(labels.any? { |label| label.start_with?("Affiliation ·") }).to be(true)
      expect(labels.any? { |label| label.start_with?("Staff tag ·") }).to be(true)
    end

    it "offers the stories and story ideas the person is credited on" do
      user = create(:user, person: person)
      create(:story, author: person)
      create(:story_idea, created_by: user)

      get comments_and_communications_path(person_id: person.id)

      labels = Nokogiri::HTML(response.body).css("select#noticeable_sgid option").map(&:text)
      expect(labels.any? { |label| label.start_with?("Story ·") }).to be(true)
      expect(labels.any? { |label| label.start_with?("Story idea ·") }).to be(true)
    end

    it "offers the reports and workshop records the person is credited on" do
      create(:monthly_report, author: person)
      create(:workshop_idea, author: person)
      create(:workshop_log, author: person)
      create(:workshop_variation, author: person)
      create(:workshop_variation_idea, author: person)

      get comments_and_communications_path(person_id: person.id)

      labels = Nokogiri::HTML(response.body).css("select#noticeable_sgid option").map(&:text)
      expect(labels.any? { |label| label.start_with?("Report ·") }).to be(true)
      expect(labels.any? { |label| label.start_with?("Workshop idea ·") }).to be(true)
      expect(labels.any? { |label| label.start_with?("Workshop log ·") }).to be(true)
      expect(labels.any? { |label| label.start_with?("Workshop variation ·") }).to be(true)
      expect(labels.any? { |label| label.start_with?("Workshop variation idea ·") }).to be(true)
    end

    it "files a note against a credited workshop log and surfaces it in the feed" do
      log = create(:workshop_log, author: person)

      expect {
        post person_comments_path(person), params: {
          for_person_id: person.id,
          commentable_sgid: log.to_sgid.to_s,
          comment: { body: "Followed up on this workshop log" }
        }
      }.to change(Comment, :count).by(1)

      expect(Comment.order(:created_at).last.commentable).to eq(log)

      get comments_and_communications_path(person_id: person.id),
          headers: { "Turbo-Frame" => "comments_and_communications_results" }
      expect(response.body).to include("Followed up on this workshop log")
    end

    it "files a note against a form submission and surfaces it in the feed" do
      submission = create(:form_submission, person: person)

      expect {
        post person_comments_path(person), params: {
          for_person_id: person.id,
          commentable_sgid: submission.to_sgid.to_s,
          comment: { body: "Reviewed their intake form" }
        }
      }.to change(Comment, :count).by(1)

      expect(Comment.order(:created_at).last.commentable).to eq(submission)

      get comments_and_communications_path(person_id: person.id),
          headers: { "Turbo-Frame" => "comments_and_communications_results" }
      expect(response.body).to include("Reviewed their intake form")
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
      # The everyone feed carries no add area — you filter to a person first, then
      # add from that person's feed. So no composers frame and no add picker here,
      # just the view-switcher that scopes the page to one person.
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("[data-controller='panel-toggle']")).to be_nil
      expect(doc.at_css("turbo-frame#cc_composers")).to be_nil
      expect(doc.at_css("select#person_id")).to be_nil
      expect(doc.at_css("select#jump_person_id")).to be_present

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

    it "shows a Responded checkbox for an incoming manual communication" do
      notification = create(:notification, :incoming, noticeable: person, recipient_email: "primary@example.com",
                                                       email_subject: "Called in", kind: "manual_log",
                                                       channel: "phone", recipient_role: "person", notification_type: 0)

      get comments_and_communications_path(person_id: person.id), headers: { "Turbo-Frame" => "comments_and_communications_results" }

      doc = Nokogiri::HTML(response.body)
      row = doc.at_css("##{ActionView::RecordIdentifier.dom_id(notification)}")
      expect(row.at_css("[data-controller='autosave'] input[name='notification[responded]'][type=checkbox]")).to be_present
    end

    it "shows a Responded checkbox for a contact-us FYI even though it's an automated, non-editable row" do
      contact_us_fyi = create(:notification, noticeable: person, recipient_email: "primary@example.com",
                                             kind: "contact_us_fyi", email_subject: "New message from the site",
                                             notification_type: 0)
      expect(contact_us_fyi.requires_response?).to be(true)
      expect(contact_us_fyi.manual_log?).to be(false)

      get comments_and_communications_path(person_id: person.id), headers: { "Turbo-Frame" => "comments_and_communications_results" }

      doc = Nokogiri::HTML(response.body)
      row = doc.at_css("##{ActionView::RecordIdentifier.dom_id(contact_us_fyi)}")
      expect(row.at_css("[data-controller='autosave'] input[name='notification[responded]'][type=checkbox]")).to be_present
      expect(row.at_css("button")).to be_nil
    end

    it "hides the Responded checkbox for a communication that doesn't need one" do
      notification = create(:notification, noticeable: person, recipient_email: "primary@example.com",
                                           email_subject: "FYI, no reply needed", kind: "manual_log",
                                           channel: "email", recipient_role: "person", notification_type: 0)
      expect(notification.requires_response?).to be(false)

      get comments_and_communications_path(person_id: person.id), headers: { "Turbo-Frame" => "comments_and_communications_results" }

      doc = Nokogiri::HTML(response.body)
      row = doc.at_css("##{ActionView::RecordIdentifier.dom_id(notification)}")
      expect(row.at_css("[data-controller='autosave']")).to be_nil
    end
  end

  describe "the combined section's link to the feed" do
    before { sign_in admin }

    it "offers one 'Comments & communications' link carrying the origin record" do
      get edit_person_path(person)

      expect(response.body).to include("Comments &amp; communications")
      expect(response.body).to include(CGI.escapeHTML(
        comments_and_communications_path(person_id: person.id, return_to_type: "Person", return_to_id: person.id)
      ))
      expect(response.body).not_to include(">Comments\n")
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

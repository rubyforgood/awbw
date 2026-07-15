class AddContentToCalloutResources < ActiveRecord::Migration[8.1]
  # Per-link copy shown on the callout card (subtitle) and the resource's own
  # detail page (page_content). Previously the handout copy was hard-coded in
  # Events::CalloutsController::HANDOUT_SUBTITLES and rendered from there; these
  # columns materialize it so admins can edit it per event.

  # Self-contained snapshot of the handout defaults so the one-time backfill
  # doesn't depend on app constants that may change later. The canonical copy
  # lives in DefaultTicketCallouts::HANDOUT_LINK_DEFAULTS for future seeds/resets.
  BACKFILL = {
    "2-Day AWBW Facilitator Training Worksheets & Handouts" => {
      subtitle: "Worksheets we'll reference throughout the training",
      page_content: "List of resources and worksheets we will reference and utilize during the training. You do not need to print them out, it may be helpful for you to access the links during the training."
    },
    "AWBW Training Workshop Worksheets" => {
      subtitle: "Create-along worksheets for the five art workshops",
      page_content: "Worksheets you can create on during all 5 of the art workshops at the training. Any art materials are welcomed during creation."
    },
    "Aha Moments" => {
      subtitle: "Reflect on the workshop and its impact",
      page_content: "Worksheet you can use to reflect on the workshop, its impact, and how you'd like to apply it."
    },
    "Inviting and Responding to Participants' Sharing" => {
      subtitle: "Support sharing and connection in breakout rooms",
      page_content: "A resource to invite and support sharing, active listening, and connection during breakout rooms."
    },
    "Letter to Supervisors" => {
      subtitle: "Secure the time and space to fully engage",
      page_content: "Letter you can share to help relieve you from competing responsibilities during the two training days. So you can secure the time and space needed to fully engage in the training."
    }
  }.freeze

  def up
    add_column :registration_ticket_callout_resources, :subtitle, :string unless column_exists?(:registration_ticket_callout_resources, :subtitle)
    add_column :registration_ticket_callout_resources, :page_content, :text unless column_exists?(:registration_ticket_callout_resources, :page_content)

    say_with_time "Backfilling handout resource content" do
      BACKFILL.each do |title, content|
        execute(ActiveRecord::Base.sanitize_sql_array([
          "UPDATE registration_ticket_callout_resources rcr " \
          "JOIN resources r ON r.id = rcr.resource_id " \
          "SET rcr.subtitle = ?, rcr.page_content = ? " \
          "WHERE r.title = ? AND rcr.subtitle IS NULL AND rcr.page_content IS NULL",
          content[:subtitle], content[:page_content], title
        ]))
      end
    end
  end

  def down
    remove_column :registration_ticket_callout_resources, :page_content, if_exists: true
    remove_column :registration_ticket_callout_resources, :subtitle, if_exists: true
  end
end

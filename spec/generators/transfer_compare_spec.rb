require "rails_helper"

# One-off artifact generator (NOT a real test). Run explicitly:
#   GEN_COMPARE=1 ai/test spec/generators/transfer_compare_spec.rb
# Writes .context/transfer_compare.html — a plain-language, admin-facing guide
# comparing every page affected by an event-registration transfer, for the
# OLD (transferred-out) reg vs the NEW (transferred-in) reg. One scrolling page.
# Guarded by GEN_COMPARE so it never runs in the normal suite / CI.
RSpec.describe "Transfer comparison artifact", type: :request do
  it "assembles the transfer comparison guide", if: ENV["GEN_COMPARE"] do
    admin = create(:user, :admin)
    sign_in admin

    person = create(:person, first_name: "Casey", last_name: "Rivera", shoutout_text: "Sharing art heals.")
    license = create(:professional_license, person: person)
    origin = create(:event, title: "Origin Training", published: true,
      cost_cents: 10_000, ce_hours_offered: 6, ce_hours_cost_cents: 10_000,
      start_date: 3.days.ago, end_date: 1.day.ago)
    dest = create(:event, title: "Destination Training", published: true,
      cost_cents: 10_000, ce_hours_offered: 6, ce_hours_cost_cents: 10_000,
      start_date: 20.days.from_now, end_date: 22.days.from_now)

    old_reg = create(:event_registration, registrant: person, event: origin,
      status: "attended", completed_day_1: true, shoutout: true, intends_to_pay: true)

    scholarship = create(:scholarship, recipient: person, amount_cents: 5_000)
    create(:allocation, source: scholarship, allocatable: old_reg, amount: 5_000)
    old_ce = old_reg.continuing_education_registrations.create!(
      professional_license: license, hours: 6, cost_cents: 10_000, skip_event_defaults: true)
    create(:allocation, source: create(:payment, amount_cents: 4_000, amount_cents_remaining: 0),
      allocatable: old_ce, amount: 4_000)

    old_reg.update!(status: "transferred_out")
    post process_transfer_event_registration_path(old_reg), params: { destination_event_id: dest.id }
    old_reg.reload
    new_reg = EventRegistration.find_by(registrant: person, event: dest)
    new_ce = new_reg.continuing_education_registrations.first

    capture = lambda do |path|
      next "<p style='padding:1rem;color:#999'>— not shown for this registration —</p>" if path.nil?
      begin
        get path
        follow_redirect! if response.redirect?
        doc = Nokogiri::HTML(response.body)
        doc.css("script, link[rel=modulepreload], noscript").remove
        (doc.at("body") || doc).inner_html
      rescue => e
        "<p style='padding:1rem;color:#c00'>error: #{ERB::Util.html_escape(e.message)}</p>"
      end
    end

    # [ group, title, plain-language description, what-to-notice, old_path, new_path ]
    rows = [
      [ "Staff pages", "Registration (staff edit)",
        "How a staff member manages this person's registration.",
        "OLD shows a purple “transferred out & locked” banner; NEW shows a teal “transferred in” banner and stays editable.",
        edit_event_registration_path(old_reg), edit_event_registration_path(new_reg) ],
      [ "Staff pages", "Continuing education / CE (staff edit)",
        "How staff manage this person's CE credit and payment.",
        "OLD keeps a paid $0-hours stub with an amber caution; NEW carries the hours + balance with a teal “transferred in” note linking to the original.",
        edit_continuing_education_registration_path(old_ce), (new_ce ? edit_continuing_education_registration_path(new_ce) : nil) ],
      [ "Staff pages", "Scholarship (staff edit)",
        "How staff manage this person's scholarship award.",
        "The award stays on the ORIGINAL registration — both sides point to the same record.",
        edit_scholarship_path(scholarship), edit_scholarship_path(scholarship) ],
      [ "Staff pages", "Manage transfer",
        "The one screen staff use to change the destination or undo a transfer.",
        "Only exists for the transferred-out reg.",
        transfer_event_registration_path(old_reg), nil ],

      [ "The registrant's ticket", "Registration ticket",
        "The page the registrant sees — their event ticket.",
        "Each ticket explains, at the top, where money/attendance live. NEW hides participation material until they belong here.",
        registration_ticket_path(old_reg.slug), registration_ticket_path(new_reg.slug) ],
      [ "The registrant's ticket", "Ticket → Payment",
        "Where the registrant pays their balance.",
        "OLD hides the “Pay” button (they pay at the new event); NEW shows it.",
        registration_payment_path(old_reg.slug), registration_payment_path(new_reg.slug) ],
      [ "The registrant's ticket", "Ticket → Scholarship",
        "The registrant's scholarship details.",
        "NEW still shows the scholarship and links back to the award on the original registration.",
        registration_scholarship_path(old_reg.slug), registration_scholarship_path(new_reg.slug) ],
      [ "The registrant's ticket", "Ticket → Continuing education (CE)",
        "The registrant's CE hours, balance, and certificate.",
        "NEW carries the hours + remaining balance; OLD shows the paid original.",
        registration_ce_path(old_reg.slug), registration_ce_path(new_reg.slug) ],
      [ "The registrant's ticket", "Ticket → Certificate",
        "The registrant's completion certificate.",
        "Earned at the event they actually attend (the NEW one).",
        registration_certificate_path(old_reg.slug), registration_certificate_path(new_reg.slug) ],
      [ "The registrant's ticket", "Ticket → Handouts",
        "Downloadable handouts for the event.",
        "Participation material — shown where they attend.",
        registration_handouts_path(old_reg.slug), registration_handouts_path(new_reg.slug) ],
      [ "The registrant's ticket", "Ticket → Videoconference",
        "The join link for a virtual event.",
        "Participation material — shown where they attend.",
        registration_videoconference_path(old_reg.slug), registration_videoconference_path(new_reg.slug) ],
      [ "The registrant's ticket", "Ticket → Staff",
        "Who's leading the event.",
        "Participation material — shown where they attend.",
        registration_staff_path(old_reg.slug), registration_staff_path(new_reg.slug) ],
      [ "The registrant's ticket", "Ticket → FAQ",
        "Frequently asked questions.",
        "Informational — the same on both.",
        registration_faq_path(old_reg.slug), registration_faq_path(new_reg.slug) ],

      [ "Billing documents", "Invoice", "The registrant's invoice.",
        "Both document the ORIGINAL event's cost.",
        registration_invoice_path(old_reg.slug), registration_invoice_path(new_reg.slug) ],
      [ "Billing documents", "Receipt", "The registrant's receipt.",
        "Both document payments made on the ORIGINAL registration.",
        registration_receipt_path(old_reg.slug), registration_receipt_path(new_reg.slug) ]
    ]

    css = Dir[Rails.root.join("public/vite-test/assets/application-*.css")].map { |f| File.read(f) }.join("\n")

    toc = rows.map.with_index { |(_g, t, *), i| "<a href='#s#{i}' style='display:block;padding:2px 0;color:#2563eb;text-decoration:none'>#{i + 1}. #{t}</a>" }.join
    out = +<<~HTML
      <!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
      <title>Event transfer — what every page looks like</title>
      <style>#{css}</style>
      <style>
        html{scrollbar-gutter:stable}
        body{margin:0;background:#f3f4f6;font-family:system-ui,sans-serif;color:#111827}
        .wrap{max-width:1400px;margin:0 auto;padding:1.5rem}
        .intro{background:#fff;border:1px solid #e5e7eb;border-radius:12px;padding:1.25rem 1.5rem;margin-bottom:1.5rem}
        .intro h1{margin:0 0 .5rem;font-size:22px}
        .intro p{margin:.35rem 0;font-size:14px;color:#374151;line-height:1.5}
        .key{display:inline-block;padding:.1rem .5rem;border-radius:9999px;font-size:12px;font-weight:600}
        .key.old{background:#f3e8ff;color:#6b21a8;border:1px solid #d8b4fe}
        .key.new{background:#ccfbf1;color:#0f766e;border:1px solid #5eead4}
        .toc{columns:3;font-size:13px;margin-top:.75rem}
        .sec{margin:0 0 2.5rem;scroll-margin-top:.5rem}
        .sechead{background:#111827;color:#fff;border-radius:10px 10px 0 0;padding:.6rem 1rem}
        .sechead .grp{font-size:11px;text-transform:uppercase;letter-spacing:.05em;color:#9ca3af}
        .sechead h2{margin:.1rem 0;font-size:17px}
        .sechead .desc{font-size:13px;color:#d1d5db;margin:0}
        .notice{background:#fffbeb;border:1px solid #fde68a;border-top:none;padding:.5rem 1rem;font-size:13px;color:#92400e}
        .notice b{color:#78350f}
        .cmp{display:grid;grid-template-columns:1fr 1fr;gap:.75rem;padding:.75rem;background:#fff;border:1px solid #e5e7eb;border-top:none;border-radius:0 0 10px 10px}
        .pane{border:1px solid #d1d5db;border-radius:8px;overflow:hidden;background:#fff}
        .panelbl{padding:.4rem .75rem;font-size:12px;font-weight:700;color:#fff}
        .old .panelbl{background:#7c3aed}.new .panelbl{background:#0d9488}
        .panebody{padding:0}
      </style></head><body><div class="wrap">
      <div class="intro">
        <h1>Event transfer — what every page looks like</h1>
        <p>When a registrant is moved from one event to another, we keep <b>two</b> registrations. This guide shows every page side by side so you can see what changes.</p>
        <p><span class="key old">LEFT · Transferred OUT</span> the original registration (they left this event). <span class="key new">RIGHT · Transferred IN</span> the new registration (where they'll attend).</p>
        <p style="color:#6b7280">Example: <b>Casey Rivera</b> transferred from <b>Origin Training</b> → <b>Destination Training</b>, carrying a scholarship and CE credit. Scroll to see each page; a yellow strip under each heading tells you what to notice.</p>
        <div class="toc">#{toc}</div>
      </div>
    HTML

    rows.each_with_index do |(group, title, desc, notice, old_path, new_path), i|
      out << "<section id='s#{i}' class='sec'>"
      out << "<div class='sechead'><div class='grp'>#{group}</div><h2>#{i + 1}. #{title}</h2><p class='desc'>#{desc}</p></div>"
      out << "<div class='notice'>👀 <b>What to notice:</b> #{notice}</div>"
      out << "<div class='cmp'>"
      out << "<div class='pane old'><div class='panelbl'>TRANSFERRED OUT · #{old_reg.event.title}</div><div class='panebody'>#{capture.call(old_path)}</div></div>"
      out << "<div class='pane new'><div class='panelbl'>TRANSFERRED IN · #{new_reg.event.title}</div><div class='panebody'>#{capture.call(new_path)}</div></div>"
      out << "</div></section>"
    end
    out << "</div></body></html>"

    path = Rails.root.join(".context/transfer_compare.html")
    File.write(path, out)
    puts "WROTE #{path} (#{(out.bytesize / 1024.0).round}kb, #{rows.size} sections)"
  end
end

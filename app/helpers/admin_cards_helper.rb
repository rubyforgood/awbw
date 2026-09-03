module AdminCardsHelper
  # -----------------------------
  # SYSTEM / ADMIN CARDS
  # -----------------------------
  def system_cards
    [
      model_card(:people, icon: "👥"),
      model_card(:users, icon: "👥",  title: "User accounts"),
      model_card(:organizations, icon: "🏫"),
      model_card(:events, icon: "📆"),
      model_card(:grants, icon: "💰"),
      model_card(:resources, icon: "📚"),
      model_card(:stories, icon: "🗣️"),
      custom_card("Story share admin", story_share_admin_path, icon: "⚙️", color: :sky, intensity: 100),
      custom_card("Staff taggings", staff_taggings_path, icon: "🏷️", color: :sky, intensity: 100),
      model_card(:workshops, icon: "🎨"),
      model_card(:workshop_variations, icon: "🔀"),
      model_card(:video_recordings, icon: "🎬", title: "Video Gallery"),
      model_card(:banners, icon: "📣"),
      model_card(:community_news, icon: "📰"),
      model_card(:faqs, icon: "❔", title: "FAQs")
    ]
  end

  # -----------------------------
  # USER CONTENT CARDS
  # -----------------------------
  def user_content_cards
    [
      custom_card("Portal activity", admin_activities_counts_path, icon: "📊"),
      custom_card("Bookmarks tally", tally_bookmarks_path, icon: "🔖"),
      custom_card(t("communications.all_section_title"), comments_and_communications_path, icon: "🗂️", color: DomainTheme.color_for(:notifications), intensity: 50),
      custom_card("Event reports", reports_events_path, icon: "📊", color: :blue),
      model_card(:scholarships, icon: "🎓"),
      model_card(:topic_subscriptions, icon: "✉️", intensity: 100, title: "Subscriptions"),
      model_card(:story_ideas, icon: "✍🏾️", intensity: 100),
      custom_card("Story share", story_shares_path, icon: "🔗", color: :sky, intensity: 100),
      custom_card("Tags", tags_path, icon: "🏷️", color: :lime, intensity: 100),
      model_card(:workshop_ideas, icon: "💡", intensity: 100),
      model_card(:workshop_variation_ideas, icon: "🔀", intensity: 100),
      model_card(:workshop_logs, icon: "📝", intensity: 100),
      model_card(:quotes, icon: "💬", intensity: 100)
    ]
  end

  # -----------------------------
  # REFERENCE CARDS
  # -----------------------------
  def reference_cards
    [
      model_card(:category_types, icon: "📂", intensity: 100),
      model_card(:categories, icon: "🗂️",
                 intensity: 100,
                 params: { published: true }),
      model_card(:sectors, icon: "🏭",
                 intensity: 100,
                 title: "Sectors",
                 params: { published: true }),
      model_card(:topic_subscription_types, icon: "✉️", intensity: 100, title: "Subscription topics"),
      custom_card("Staff tags", staff_tags_path, icon: "🏷️", color: :lime, intensity: 100),
      custom_card("Windows audiences", windows_types_path, icon: "🪟")
    ]
  end

  # -----------------------------
  # DEDUPER CARDS
  # -----------------------------
  def deduper_cards
    [
      custom_card("Dedupe people", dedupe_index_people_path, icon: "🧹", color: DomainTheme.color_for(:people), intensity: 100),
      custom_card("Dedupe organizations", dedupe_index_organizations_path, icon: "🧹", color: DomainTheme.color_for(:organizations), intensity: 100),
      custom_card("Dedupe categories", dedupe_index_categories_path, icon: "🧹", color: DomainTheme.color_for(:categories), intensity: 100),
      custom_card("Dedupe sectors", dedupe_index_sectors_path, icon: "🧹", color: DomainTheme.color_for(:sectors), intensity: 100)
    ]
  end

  # -----------------------------
  # DEPRECATED DATA CARDS
  # -----------------------------
  def deprecated_data_cards
    [
      custom_card("Organization statuses", organization_statuses_path, icon: "🧮", color: :emerald, intensity: 100)
    ]
  end

  # -----------------------------
  # ADDITIONAL DATA CARDS
  # -----------------------------
  def additional_data_cards
    [
      custom_card("Allocations", allocations_path, icon: "📤", color: :sky, intensity: 100),
      custom_card("Bulk payments", bulk_payments_path, icon: "💳", color: :sky, intensity: 100),
      custom_card("Event registrations", event_registrations_path, icon: "🎟️", color: :sky, intensity: 100),
      custom_card("Features & tips", features_path, icon: "⭐", color: :sky, intensity: 100),
      custom_card("Forms", forms_path, icon: "📋", color: :sky, intensity: 100),
      custom_card("Licenses", professional_licenses_path, icon: "🪪", color: :sky, intensity: 100),
      custom_card("Form submissions", form_submissions_path, icon: "📨", color: :sky, intensity: 100),
      custom_card("Form answers", form_answers_path, icon: "✅", color: :sky, intensity: 100),
      custom_card("Monthly reports", monthly_reports_path, icon: "📈", color: :sky, intensity: 100),
      custom_card("Payments", payments_path, icon: "💳", color: :sky, intensity: 100),
      custom_card("Bookmarks", bookmarks_path, icon: "🔖", color: :sky, intensity: 100),
      custom_card("CE registrations", continuing_education_registrations_path, icon: "📜", color: :sky, intensity: 100),
      custom_card("Comments", comments_path, icon: "💬", color: :sky, intensity: 100),
      custom_card(t("communications.title"), notifications_path, icon: "🔔", color: :sky, intensity: 100),
      custom_card("Tagging counts", taggings_matrix_path, icon: "🧮", color: :sky, intensity: 100),
      disabled_card("Affiliations", icon: "🤝"),
      disabled_card("Reports", icon: "📄"),
      disabled_card("Discounts", icon: "💲"),
      disabled_card("Refunds", icon: "↩️"),
      disabled_card("Event staff", icon: "🧑‍💼")
    ].sort_by { |card| card[:title].downcase.gsub(" ", "~") }
  end

  # ============================================================
  # CARD BUILDERS
  # ============================================================
  def model_card(key, title: nil, icon:, intensity: 50, params: {})
    {
      title: title || key.to_s.humanize,
      path: polymorphic_path(key.to_s.classify.constantize, params),
      icon: icon,
      bg_color: DomainTheme.bg_class_for(key, intensity: intensity),
      hover_bg_color: DomainTheme.bg_class_for(key, intensity: intensity == 50 ? 100 : intensity + 100, hover: true),
      text_color: "text-gray-800"
    }
  end

  def custom_card(title, path, icon:, color: :gray, intensity: 50)
    {
      title: title,
      path: path,
      icon: icon,
      bg_color: "bg-#{color}-#{intensity}",
      hover_bg_color: "hover:bg-#{color}-#{intensity == 50 ? 100 : intensity + 100}",
      text_color: "text-gray-800"
    }
  end

  def disabled_card(title, icon:)
    {
      title: title,
      icon: icon,
      disabled: true,
      bg_color: "bg-gray-100",
      text_color: "text-gray-400"
    }
  end
end

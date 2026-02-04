module AdminCardsHelper
  # -----------------------------
  # SYSTEM / ADMIN CARDS
  # -----------------------------
  def system_cards
    [
      model_card(:banners, icon: "📣"),
      model_card(:facilitators, icon: "🧑‍🎨"),
      model_card(:faqs, icon: "❔", title: "FAQs"),
      model_card(:community_news, icon: "📰"),
      model_card(:events, icon: "📆"),
      model_card(:stories, icon: "🗣️"),
      custom_card("Tagging counts", taggings_matrix_path, icon: "🧮", color: :lime),
      model_card(:resources, icon: "📚"),
      model_card(:workshops, icon: "🎨"),
      model_card(:projects, icon: "🏫"),
      model_card(:users, icon: "👥",  title: "User accounts")
    ]
  end

  # -----------------------------
  # USER CONTENT CARDS
  # -----------------------------
  def user_content_cards
    [
      custom_card("Activity charts", admin_activities_charts_path, icon: "📊"),
      custom_card("Activity counts", admin_activities_counts_path, icon: "🔢"),
      custom_card("Activity logs", admin_activities_events_path, icon: "🧭"),
      custom_card("Bookmarks tally", tally_bookmarks_path, icon: "🔖"),
      model_card(:event_registrations, icon: "🎟️", intensity: 100),
      model_card(:story_ideas, icon: "✍️", intensity: 100),
      custom_card("Tags", tags_path, icon: "🏷️", color: :lime, intensity: 100),
      model_card(:workshop_variations, icon: "🔀", intensity: 100),
      model_card(:workshop_ideas, icon: "💡", intensity: 100),
      model_card(:workshop_logs, icon: "📝", intensity: 100),
      model_card(:quotes, icon: "💬", intensity: 100),
      custom_card("System notifications", notifications_path, icon: "🔔")
    ]
  end

  # -----------------------------
  # REFERENCE CARDS
  # -----------------------------
  def reference_cards
    [
      model_card(:categories, icon: "🗂️",
                 intensity: 100,
                 params: { published: true }),
      model_card(:sectors, icon: "🏭",
                 intensity: 100,
                 title: "Service populations",
                 params: { published: true }),
      custom_card("Organization statuses", organization_statuses_path, icon: "🧮", color: :emerald, intensity: 100),
      custom_card("Windows types", windows_types_path, icon: "🪟")
    ]
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
end

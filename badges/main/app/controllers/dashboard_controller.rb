class DashboardController < ApplicationController
  skip_before_action :authenticate_user!, only: :help

  def index
    workshops = current_user.curriculum(Workshop)
      .featured.includes(:sectors).decorate
    @featured_workshops = workshops.sort { |x, y| Date.parse(y.date) <=> Date.parse(x.date) }

    @popular_resources = Resource.published.featured.where(kind: [nil, "Resource",
      "Template", "Handout", "Scholarship", "Toolkit", "Form"])
      .decorate

    @stories = Resource.story.featured.decorate
  end

  def admin
    if current_user.super_user?
      @user_content_cards = [

        { title: "Bookmarks tally", path: root_path, icon: "🔖" },
        { title: "Quotes", path: root_path, icon: "💬" },
        { title: "Stories", path: root_path, icon: "🗣️" },
        { title: "Vision Seeds", path: root_path, icon: "🌱" },
        { title: "Annual Reports", path: root_path, icon: "📊" },
        { title: "Workshop Logs", path: workshop_logs_path, icon: "📝" },
        { title: "Workshops", path: workshops_path, icon: "🎨" },
        { title: "Workshop Ideas", path: root_path, icon: "💡" },
        { title: "Workshop Variations", path: workshop_variations_path, icon: "🔀" },
      ]

      @system_cards = [
        { title: "Banners", path: root_path, icon: "📣" },
        { title: "Events", path: events_path, icon: "📆" },
        { title: "FAQs", path: faqs_path, icon: "❔" },
        { title: "Forms", path: root_path, icon: "📋" },
        { title: "Organizations", path: root_path, icon: "🏫" },
        { title: "Resources", path: resources_path, icon: "📚" },
        { title: "Users", path: users_path, icon: "👥" },

      ]

      @reference_cards = [

        { title: "Age ranges", path: root_path, icon: "👶" },
        { title: "Categories", path: root_path, icon: "🗂️" },
        { title: "Sectors", path: root_path, icon: "🏭" },
        # { title: "WindowsTypes", path: root_path, icon: "🪟" },
        # { title: "FormFields", path: root_path, icon: "✏️" },
        # { title: "FormAnswerOptions", path: root_path, icon: "🗳️" },
      ]
    else
      redirect_to root_path, alert: 'You do not have permission.'
    end
  end

  def recent_activity
    @recent_activity = current_user.recent_activity(20)
  end
end

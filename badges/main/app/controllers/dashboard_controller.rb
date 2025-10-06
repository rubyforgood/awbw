class DashboardController < ApplicationController
  skip_before_action :authenticate_user!, only: :help

  def index
    workshops = current_user.curriculum(Workshop)
                            .featured
                            .includes(:sectors)
                            .decorate
    @featured_workshops = workshops.sort { |x, y| Date.parse(y.date) <=> Date.parse(x.date) }

    @popular_resources = Resource.featured
                                 .published
                                 .popular
                                 .order(ordering: :asc, created_at: :desc)
                                 .decorate

    @stories = Resource.story.featured.decorate
  end

  def admin
    if current_user.super_user?
      @user_content_cards = [

        { title: "Bookmarks tally", path: authenticated_root_path, icon: "🔖" },
        { title: "Quotes", path: authenticated_root_path, icon: "💬" },
        { title: "Stories", path: authenticated_root_path, icon: "🗣️" },
        { title: "Vision Seeds", path: authenticated_root_path, icon: "🌱" },
        { title: "Annual Reports", path: authenticated_root_path, icon: "📊" },
        { title: "Workshop Logs", path: workshop_logs_path, icon: "📝" },
        { title: "Workshops", path: workshops_path, icon: "🎨" },
        { title: "Workshop Ideas", path: authenticated_root_path, icon: "💡" },
        { title: "Workshop Variations", path: workshop_variations_path, icon: "🔀" },
      ]

      @system_cards = [
        { title: "Banners", path: authenticated_root_path, icon: "📣" },
        { title: "Events", path: events_path, icon: "📆" },
        { title: "FAQs", path: faqs_path, icon: "❔" },
        { title: "Forms", path: authenticated_root_path, icon: "📋" },
        { title: "Organizations", path: authenticated_root_path, icon: "🏫" },
        { title: "Resources", path: resources_path, icon: "📚" },
        { title: "Users", path: users_path, icon: "👥" },

      ]

      @reference_cards = [

        { title: "Age ranges", path: authenticated_root_path, icon: "👶" },
        { title: "Categories", path: authenticated_root_path, icon: "🗂️" },
        { title: "Sectors", path: authenticated_root_path, icon: "🏭" },
        # { title: "WindowsTypes", path: authenticated_root_path, icon: "🪟" },
        # { title: "FormFields", path: authenticated_root_path, icon: "✏️" },
        # { title: "FormAnswerOptions", path: authenticated_root_path, icon: "🗳️" },
      ]
    else
      redirect_to authenticated_root_path, alert: 'You do not have permission.'
    end
  end

  def recent_activities
    @user = (current_user.super_user? && params[:user_id].present?) ? User.find(params[:user_id]) : current_user
    @recent_activities = @user.recent_activity(params[:limit] || 20)
                              .paginate(page: params[:page], per_page: params[:per_page] || 20)
  end
end

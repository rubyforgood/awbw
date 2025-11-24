class DashboardController < ApplicationController
  skip_before_action :authenticate_user!, only: :help

  def index
    workshops = Workshop.featured
                        .published
                        .includes(:sectors)
                        .decorate
    @workshops = workshops.sort { |x, y| Date.parse(y.date) <=> Date.parse(x.date) }

    @resources = Resource.featured
                         .published
                         .published_kinds
                         .order(ordering: :asc, created_at: :desc)
                         .decorate

    @stories = Story.featured.published.order(:title).decorate
    @community_news = CommunityNews.featured.published.order(updated_at: :desc).decorate
    @events = Event.featured.publicly_visible.order(:start_date).decorate
  end

  def admin
    if current_user.super_user?
      @user_content_cards = [
        { title: "Bookmarks tally", path: tally_bookmarks_path, icon: "🔖",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "Recent Activity", path: dashboard_recent_activities_path, icon: "🧭",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "Event Registrations", path: event_registrations_path, icon: "🎟️",
          bg_color: "bg-blue-100", text_color: "text-blue-800" },
        { title: "!!!Quotes", path: authenticated_root_path, icon: "💬",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "Story Ideas", path: story_ideas_path, icon: "✍️️",
          bg_color: "bg-rose-100", text_color: "text-rose-800" },
        { title: "Workshop Variations", path: workshop_variations_path, icon: "🔀",
          bg_color: "bg-purple-100", text_color: "text-purple-800" },
        { title: "Workshop Ideas", path: workshop_ideas_path, icon: "💡",
          bg_color: "bg-indigo-100", text_color: "text-indigo-800" },


        { title: "!!!Vision Seeds", path: authenticated_root_path, icon: "🌱",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "!!!Annual Reports", path: authenticated_root_path, icon: "📊",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "Workshop Logs", path: workshop_logs_path, icon: "📝",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
      ]

      @system_cards = [
        { title: "Banners", path: banners_path, icon: "📣",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "CommunityNews", path: community_news_index_path, icon: "📣",
          bg_color: "bg-orange-50", text_color: "text-gray-800" },
        { title: "Events", path: events_path, icon: "📆",
          bg_color: "bg-blue-50", text_color: "text-gray-800" },
        { title: "FAQs", path: faqs_path, icon: "❔",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "Stories", path: stories_path, icon: "🗣️",
          bg_color: "bg-rose-50", text_color: "text-gray-800" },
        { title: "Resources", path: resources_path, icon: "📚",
          bg_color: "bg-violet-50", text_color: "text-gray-800" },
        { title: "Workshops", path: workshops_path, icon: "🎨",
          bg_color: "bg-indigo-50", text_color: "text-gray-800" },




        { title: "Facilitators", path: facilitators_path, icon: "🧑‍🎨",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "Organizations", path: projects_path, icon: "🏫",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "Users", path: users_path, icon: "👥",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "!!!Forms", path: authenticated_root_path, icon: "📋",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },

      ]

      @reference_cards = [

        { title: "!!!Age ranges", path: authenticated_root_path, icon: "👶",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "!!!Categories", path: authenticated_root_path, icon: "🗂️",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "!!!Sectors", path: authenticated_root_path, icon: "🏭",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        { title: "!!!Project Statuses", path: authenticated_root_path, icon: "🧮️",
          bg_color: "bg-gray-50", text_color: "text-gray-800" },
        # { title: "WindowsTypes", path: authenticated_root_path, icon: "🪟",
        #           bg_color: "bg-gray-50", text_color: "text-gray-800" },
        # { title: "FormFields", path: authenticated_root_path, icon: "✏️",
        #           bg_color: "bg-gray-50", text_color: "text-gray-800" },
        # { title: "FormAnswerOptions", path: authenticated_root_path, icon: "🗳️",
        #           bg_color: "bg-gray-50", text_color: "text-gray-800" },
      ]
    else
      redirect_to authenticated_root_path, alert: 'You do not have permission.'
    end
  end

  def recent_activities
    @user = (current_user.super_user? && params[:user_id].present?) ? User.find(params[:user_id]) : current_user
    if params[:user_id] && params[:user_id].empty?
      recent = []
      recent.concat(User.order(updated_at: :desc).limit(10))
      recent.concat(Facilitator.order(updated_at: :desc).limit(10))
      recent.concat(Banner.order(updated_at: :desc).limit(10))
      recent.concat(Faq.order(updated_at: :desc).limit(10))
      recent.concat(Event.order(updated_at: :desc).limit(10))
      recent.concat(EventRegistration.order(updated_at: :desc).limit(10))
      recent.concat(Workshop.order(updated_at: :desc).limit(10))
      recent.concat(WorkshopIdea.order(updated_at: :desc).limit(10))
      recent.concat(WorkshopLog.order(updated_at: :desc).limit(10))
      recent.concat(WorkshopVariation.order(updated_at: :desc).limit(10))
      recent.concat(Story.order(updated_at: :desc).limit(10))
      recent.concat(StoryIdea.order(updated_at: :desc).limit(10))
      recent.concat(Quote.order(updated_at: :desc).limit(10))
      recent.concat(Resource.order(updated_at: :desc).limit(10))
      recent.concat(Report.where(owner_type: 'MonthlyReport').order(updated_at: :desc).limit(10))
      # recent.concat(Report.where(owner_id: 7).order(updated_at: :desc).limit(10)) # TODO: remove hard-coded

      # Sort by the most recent timestamp (updated_at preferred, fallback to created_at)
      recent_activities = recent.sort_by { |item|
        item.try(:updated_at) || item.created_at }
                                 .reverse.first(10 * 8)
    else
      recent_activities = @user.recent_activity(params[:limit] || 20)
    end
    @recent_activities = recent_activities
                           .paginate(page: params[:page],
                                     per_page: params[:per_page] || 20)
  end
end

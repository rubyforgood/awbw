module Admin
  class AhoyActivitiesController < ApplicationController
    helper_method :scoped_visits, :scoped_events

    def index
      authorize! :ahoy_activity, to: :index?

      @person = Person.find_by(id: params[:person_id]) if params[:person_id].present?

      # The full page renders only the header, filters, and an empty results frame;
      # the frame's src request (turbo_frame_request?) loads the filtered rows.
      return render :index unless turbo_frame_request?

      @users = params[:user_id].present? ? User.where(id: params[:user_id].to_s.split("--")) : nil

      page = params[:page].presence&.to_i || 1
      per_page = params[:per_page].presence&.to_i || 20

      scope = Ahoy::Event.includes(:user, :visit).order(time: :desc)

      # Only real content interactions (not search/filter noise)
      if params[:prefixes].present?
        prefixes = params[:prefixes].split("--").map(&:strip)
      else
        prefixes = nil # %w[ create update destroy auth ] # view browse print download
      end
      if prefixes.present?
        scope = scope.where(prefixes.map { |p| "ahoy_events.name LIKE ?" }.join(" OR "),
                            *prefixes.map { |p| "#{p}.%" })
      end

      # Filter by event name. Split on any non-alphanumeric run so hyphens (and
      # commas, dots, spaces) are interchangeable separators and each token must
      # match — e.g. "account-auth" finds "auth.account_deactivated".
      if params[:event_name].present?
        params[:event_name].split(/[^a-z0-9]+/i).reject(&:blank?).each do |token|
          scope = scope.where("ahoy_events.name LIKE ?", "%#{Ahoy::Event.sanitize_sql_like(token)}%")
        end
      end

      # Filter by user (if viewing specific user activity)
      scope = scope.where(user: @users) if @users.present?

      # Time filter
      scope = scope.where(time: time_range) if time_range.present?

      if params[:from].present?
        from_time = Time.zone.parse(params[:from]).beginning_of_day
        scope = scope.where("ahoy_events.time >= ?", from_time)
      end

      if params[:to].present?
        to_time = Time.zone.parse(params[:to]).end_of_day
        scope = scope.where("ahoy_events.time <= ?", to_time)
      end

      # Filter by visit
      if params[:visit_id].present?
        scope = scope.where(visit_id: params[:visit_id])
      end

      # Filter by props (full-text search across properties JSON)
      if params[:props].present?
        term = Ahoy::Event.sanitize_sql_like(params[:props])
        scope = scope.where(
          "CAST(ahoy_events.properties AS CHAR) LIKE ?",
          "%#{term}%"
        )
      end

      # Audience filter
      scope = apply_audience_filter(scope)

      # Filter by resource type and ID
      if params[:resource_type].present?
        scope = scope.where(resource_type: params[:resource_type])
      end

      if params[:resource_id].present?
        scope = scope.where(resource_id: params[:resource_id])
      end

      # Filter to a person's full history: the person, their user, and every
      # associated record (see Analytics::PersonActivityEvents).
      if @person
        scope = scope.where(id: Analytics::PersonActivityEvents.new(@person).relation.select(:id))
        # Notifications aren't ahoy-tracked, so surface the person's
        # communications straight from the notifications table.
        email = @person.communications_email
        @person_communications = email.present? ?
          Notification.email(email).includes(:noticeable, sender: :person).order(created_at: :desc).limit(10) :
          Notification.none

        # Attendance sign-ins happen on a login-free public callout (no Current),
        # so they aren't ahoy-tracked either — read the entries directly.
        @person_time_entries = EventAttendanceTimeEntry
          .where(event_registration_id: @person.event_registrations.select(:id))
          .includes(event_registration: :event)
          .order(signed_in_at: :desc)
          .limit(15)
          .decorate
      end

      @events = scope.paginate(page: page, per_page: per_page)

      render :activity_results
    end

    def show
      authorize! :ahoy_activity, to: :show?
      @event = Ahoy::Event.includes(:user, :visit).find(params[:id])
      @resource_path = safe_resource_path(@event.resource_type, @event.resource_id)
    end

    def visits
      authorize! :ahoy_activity, to: :visits?

      page     = params[:page].presence&.to_i || 1
      per_page = params[:per_page].presence&.to_i || 20

      scope = Ahoy::Visit
                .includes(:user)
                .left_joins(:events)
                .select("ahoy_visits.*, COUNT(ahoy_events.id) AS events_count")
                .group("ahoy_visits.id")
                .order(started_at: :desc)

      # Filter by user
      if params[:user_id].present?
        scope = scope.where(user_id: params[:user_id])
      end

      # Filter by visit
      if params[:visit_id].present?
        scope = scope.where(id: params[:visit_id])
      end

      # Time period filter
      scope = scope.where(started_at: time_range) if time_range

      # Audience filter
      scope = apply_audience_filter(scope)

      # Date filtering
      if params[:from].present?
        from_time = Time.zone.parse(params[:from]).beginning_of_day
        scope = scope.where("ahoy_visits.started_at >= ?", from_time)
      end

      if params[:to].present?
        to_time = Time.zone.parse(params[:to]).end_of_day
        scope = scope.where("ahoy_visits.started_at <= ?", to_time)
      end

      @visits = scope.paginate(page: page, per_page: per_page)
    end

    def charts
      authorize! :ahoy_activity, to: :charts?
      prepare_chart_data
      prepare_portal_usage_data
      prepare_content_creation_data
      creation_velocity_data
    end

    private

    def prepare_chart_data
      events = scoped_events

      # Workshop filter/search categories - pluck once, reuse for both type and name charts
      ws_categories_raw = events
        .where(name: [ "filter.workshops", "search.workshops" ])
        .pluck(Arel.sql("JSON_EXTRACT(properties, '$.filters.categories')"))
        .flat_map { |arr| safe_json_parse(arr) }

      @ws_category_types = ws_categories_raw
        .map { |c| c["type"] }.compact.tally
        .sort_by { |_k, v| -v }.first(10).to_h

      @ws_category_names = ws_categories_raw
        .map { |c| c["name"] }.compact.tally
        .sort_by { |_k, v| -v }.first(15).to_h

      # Workshop filter/search sectors
      @ws_sectors = events
        .where(name: [ "filter.workshops", "search.workshops" ])
        .pluck(Arel.sql("JSON_EXTRACT(properties, '$.filters.sectors')"))
        .flat_map { |arr| safe_json_parse(arr) }
        .map { |s| s["name"] }.compact.tally
        .sort_by { |_k, v| -v }.first(10).to_h

      # Workshop keyword searches
      ws_search = events.where(name: "search.workshops")

      @ws_search_titles = ws_search
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.keywords.title'))"))
        .compact.reject(&:blank?).tally
        .sort_by { |_k, v| -v }.first(10).to_h

      @ws_search_authors = ws_search
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.keywords.author'))"))
        .compact.reject(&:blank?).tally
        .sort_by { |_k, v| -v }.first(10).to_h

      @ws_search_full_text = ws_search
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.keywords.full_text'))"))
        .compact.reject(&:blank?).map(&:downcase).tally
        .sort_by { |_k, v| -v }.first(10).to_h

      # Windows types - batch lookup
      wt_raw = events
        .where(name: [ "filter.workshops", "search.workshops" ])
        .pluck(Arel.sql("JSON_EXTRACT(properties, '$.filters.windows_types')"))
        .flat_map { |arr| safe_json_parse(arr) }
      wt_ids = wt_raw.map { |wt| wt.is_a?(Hash) ? wt["id"] : wt }.compact
      wt_names = WindowsType.where(id: wt_ids.uniq).pluck(:id, :short_name).to_h
      @ws_windows_types = wt_ids
        .map { |id| wt_names[id] }.compact.tally
        .sort_by { |_k, v| -v }.first(10).to_h

      # Zero-result searches
      @ws_zero_results = events
        .where("name LIKE 'search_zero.%'")
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.query'))"))
        .compact.reject(&:blank?).tally
        .sort_by { |_k, v| -v }.first(10).to_h

      # Workshop funnel - batch count
      ws_funnel_names = [
        "search.workshops", "filter.workshops",
        "view.workshop", "print.workshop", "download.workshop"
      ]
      ws_funnel_counts = events.where(name: ws_funnel_names).group(:name).count
      @ws_funnel = {
        "Keyword search" => ws_funnel_counts["search.workshops"] || 0,
        "Checkbox filter" => ws_funnel_counts["filter.workshops"] || 0,
        "View" => ws_funnel_counts["view.workshop"] || 0,
        "Print" => ws_funnel_counts["print.workshop"] || 0,
        "Download" => ws_funnel_counts["download.workshop"] || 0
      }

      # Resource search keywords
      @rs_keywords = events
        .where(name: "search.resources")
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.keywords.full_text'))"))
        .compact.reject(&:blank?).map(&:downcase).tally
        .sort_by { |_k, v| -v }.first(12).to_h

      # Resource filter kinds
      @rs_kinds = events
        .where(name: "filter.resources")
        .pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.filters.kind'))"))
        .compact.reject(&:blank?).tally
        .sort_by { |_k, v| -v }.to_h

      # Resource funnel - batch count
      rs_funnel_names = [
        "search.resources", "filter.resources",
        "view.resource", "print.resource", "download.resource"
      ]
      rs_funnel_counts = events.where(name: rs_funnel_names).group(:name).count
      @rs_funnel = {
        "Keyword search" => rs_funnel_counts["search.resources"] || 0,
        "Kind filter" => rs_funnel_counts["filter.resources"] || 0,
        "View" => rs_funnel_counts["view.resource"] || 0,
        "Print" => rs_funnel_counts["print.resource"] || 0,
        "Download" => rs_funnel_counts["download.resource"] || 0
      }

      # Tag analytics metrics
      @tags_page_views = events.where(name: "view.tags").count
      @taggings_page_views = events.where(name: "view.taggings").count

      # Tagging sectors and categories
      tagging_events = events.where(name: "search.taggings")
      tagging_count = tagging_events.count
      @tagging_searches = tagging_count

      @tagging_sectors = tagging_events
        .pluck(Arel.sql("JSON_EXTRACT(properties, '$.sectors')"))
        .flat_map { |arr| safe_json_parse(arr) }
        .tally.sort_by { |_k, v| -v }.first(15).to_h

      @tagging_categories = tagging_events
        .pluck(Arel.sql("JSON_EXTRACT(properties, '$.categories')"))
        .flat_map { |arr| safe_json_parse(arr) }
        .tally.sort_by { |_k, v| -v }.first(15).to_h

      # Search complexity: how many filters per search
      raw_searches = tagging_events
        .pluck(
          Arel.sql("JSON_EXTRACT(properties, '$.sectors')"),
          Arel.sql("JSON_EXTRACT(properties, '$.categories')")
        )
      @tagging_search_complexity = { "1 filter" => 0, "2 filters" => 0, "3 filters" => 0, "4 filters" => 0, "5+ filters" => 0 }
      combo_tallies = Hash.new(0)
      raw_searches.each do |sectors_json, categories_json|
        sectors = safe_json_parse(sectors_json)
        categories = safe_json_parse(categories_json)
        total = sectors.size + categories.size
        bucket = case total
        when 0..1 then "1 filter"
        when 2 then "2 filters"
        when 3 then "3 filters"
        when 4 then "4 filters"
        else "5+ filters"
        end
        @tagging_search_complexity[bucket] += 1

        combo = (sectors.sort + categories.sort).join(" + ")
        combo_tallies[combo] += 1 if combo.present?
      end

      @top_filter_combos = combo_tallies
        .sort_by { |_k, v| -v }
        .first(12).to_h

      # Tagging search origin: was the immediately preceding event a tags page view?
      search_event_ids = tagging_events.pluck(:id, :visit_id, :time)
      via_tags = 0
      via_taggings = 0
      search_event_ids.each do |id, visit_id, time|
        preceding = events.where(visit_id: visit_id)
                          .where("time <= ? AND id < ?", time, id)
                          .order(time: :desc, id: :desc)
                          .limit(1)
                          .pick(:name)
        if preceding == "view.tags"
          via_tags += 1
        else
          via_taggings += 1
        end
      end
      @tagging_search_origin = {
        "Via tags page" => via_tags,
        "Via taggings page" => via_taggings
      }

      # User discovery funnel - batch with LIKE patterns
      @discovery_funnel = {
        "Views" => events.where("name LIKE 'view.%'").count,
        "Prints" => events.where("name LIKE 'print.%'").count,
        "Downloads" => events.where("name LIKE 'download.%'").count,
        "Keyword searches" => events.where("name LIKE 'search.%'").count,
        "Checkbox filters" => events.where("name LIKE 'filter.%'").count,
        "Taggings" => tagging_count
      }

      # Content discovery pie chart - reuse cached counts
      @content_discovery = {
        "Keyword searches" => ws_funnel_counts["search.workshops"] || 0,
        "Checkbox filters" => ws_funnel_counts["filter.workshops"] || 0,
        "Tagging pages" => tagging_count
      }

      visits = scoped_visits

      # Average events per visit
      total_visits = visits.count
      total_events = events.count
      @avg_events_per_visit = total_visits > 0 ? (total_events.to_f / total_visits).round(1) : 0

      # Bounce rate (single vs multi-event visits)
      @bounce_rate = {
        "Single-event" => events.group(:visit_id).having("count(*) = 1").count.size,
        "Multi-event" => events.group(:visit_id).having("count(*) > 1").count.size
      }

      # Top engaged users (non-admin)
      @top_engaged_users = events
        .joins("INNER JOIN users ON users.id = ahoy_events.user_id")
        .where(users: { super_user: false })
        .group(Arel.sql("CONCAT(users.first_name, ' ', users.last_name)"))
        .count
        .sort_by { |_k, v| -v }
        .first(10).to_h

      # User activity level distribution
      user_event_counts = events
        .where.not(user_id: nil)
        .group(:user_id)
        .count
        .values
      active_user_ids = events.where.not(user_id: nil).distinct.pluck(:user_id)
      never_active = User.where.not(id: active_user_ids).count
      @user_activity_distribution = { "Never active" => never_active, "Light (1-9)" => 0,
                                      "Regular (10-49)" => 0, "Power (50+)" => 0 }
      user_event_counts.each do |c|
        bucket = case c
        when 1..9 then "Light (1-9)"
        when 10..49 then "Regular (10-49)"
        else "Power (50+)"
        end
        @user_activity_distribution[bucket] += 1
      end

      # Search-to-view conversion
      total_search_visits = events.where("name LIKE 'search.%'").distinct.count(:visit_id)
      if total_search_visits > 0
        search_visit_ids = events.where("name LIKE 'search.%'").select(:visit_id).distinct
        viewed_after_search = events.where(visit_id: search_visit_ids)
          .where("name LIKE 'view.%'").distinct.count(:visit_id)
        @search_conversion = {
          "Searched & Viewed" => viewed_after_search,
          "Searched & Left" => total_search_visits - viewed_after_search
        }
      else
        @search_conversion = {}
      end

      # Session duration distribution
      duration_sub = visits.joins(:events)
        .select("ahoy_visits.id, TIMESTAMPDIFF(MINUTE, ahoy_visits.started_at, MAX(ahoy_events.time)) as dm")
        .group("ahoy_visits.id")
      raw_durations = ActiveRecord::Base.connection.select_values(
        "SELECT dm FROM (#{duration_sub.to_sql}) AS d WHERE dm IS NOT NULL"
      )
      @session_duration_chart = { "< 1 min" => 0, "1-5 min" => 0, "5-15 min" => 0,
                                  "15-30 min" => 0, "30-60 min" => 0, "60+ min" => 0 }
      raw_durations.each do |d|
        bucket = case d.to_i
        when 0 then "< 1 min"
        when 1..5 then "1-5 min"
        when 6..15 then "5-15 min"
        when 16..30 then "15-30 min"
        when 31..60 then "30-60 min"
        else "60+ min"
        end
        @session_duration_chart[bucket] += 1
      end

      # Average session duration (minutes)
      if raw_durations.any?
        @avg_session_minutes = (raw_durations.sum(&:to_f) / raw_durations.size).round(1)
      else
        @avg_session_minutes = 0
      end

      # New vs returning visitors
      visitor_counts = visits.group(:visitor_token).count
      @new_vs_returning = {
        "New" => visitor_counts.count { |_k, v| v == 1 },
        "Returning" => visitor_counts.count { |_k, v| v > 1 }
      }

      # Heatmap: events by hour × day of week (in user's timezone)
      tz_name = ActiveSupport::TimeZone[Time.zone.name].tzinfo.canonical_identifier
      @heatmap_data = events.group(
        Arel.sql("HOUR(CONVERT_TZ(time, 'UTC', '#{tz_name}'))"),
        Arel.sql("DAYOFWEEK(CONVERT_TZ(time, 'UTC', '#{tz_name}'))")
      ).count
      @user_tz_abbr = Time.zone.now.strftime("%Z")

      # Top exit events (last event per visit)
      last_event_ids = events.group(:visit_id).select("MAX(ahoy_events.id)")
      @top_exit_events = Ahoy::Event
        .where(id: last_event_ids)
        .group(:name)
        .count
        .sort_by { |_k, v| -v }
        .first(10).to_h

      # Top referrer → landing page combos (with wrapped labels)
      @top_referrer_landing = visits.group(:referring_domain, :landing_page)
        .count
        .sort_by { |_k, v| -v }
        .first(10)
        .map { |(domain, page), count| [ wrap_label("#{domain || '(direct)'} → #{page}", 30), count ] }
        .to_h
    end

    def prepare_portal_usage_data
      audiences = selected_audiences

      # Determine which user scope to show based on audience filter
      @audience_labels = audiences.sort
      has_users = audiences.include?("users")
      has_staff = audiences.include?("staff")
      user_scope = if has_users && has_staff
        User.all
      elsif has_staff
        User.where(super_user: true)
      elsif has_users
        User.where(super_user: false)
      else
        User.none
      end

      # Total users in the system (always show full picture)
      @total_users = User.count
      @staff_users = User.where(super_user: true).count
      @non_staff_users = User.where(super_user: false).count

      # Filtered counts
      @filtered_user_count = user_scope.count
      @portal_access_users = user_scope.where.not(welcome_instructions_sent_at: nil).count
      @has_access_users = user_scope.has_access.count
      @confirmed_users = user_scope.where.not(confirmed_at: nil).count
      @authenticated_users = user_scope.where("sign_in_count > 0").count

      login_events = scoped_events.where(name: "auth.login")

      # Visits split by visitor vs logged-in user
      @authenticated_visits = scoped_visits.where.not(user_id: nil).count
      @public_visits = scoped_visits.where(user_id: nil).count
      total_events = scoped_events.count
      public_events = scoped_events.where(user_id: nil).count
      @public_events_pct = total_events > 0 ? (public_events.to_f / total_events * 100).round(0) : 0
      total_visits = @authenticated_visits + @public_visits
      @public_visits_pct = total_visits > 0 ? (@public_visits.to_f / total_visits * 100).round(0) : 0
      @visitor_visits_by_day = scoped_visits.where(user_id: nil).group_by_day(:started_at).count
      @user_visits_by_day = scoped_visits.where.not(user_id: nil).group_by_day(:started_at).count

      # Login count over time (total logins per day)
      @logins_by_day = login_events.group_by_day(:time).count

      # Visits by day
      @visits_by_day = scoped_visits.group_by_day(:started_at).count

      # Distribution of user login frequency
      login_counts = login_events
        .where.not(user_id: nil)
        .group(:user_id)
        .count
        .values
      @login_frequency = { "1 login" => 0, "2-5 logins" => 0, "6-10 logins" => 0,
                           "11-25 logins" => 0, "26-50 logins" => 0, "51+ logins" => 0 }
      login_counts.each do |c|
        bucket = case c
        when 1 then "1 login"
        when 2..5 then "2-5 logins"
        when 6..10 then "6-10 logins"
        when 11..25 then "11-25 logins"
        when 26..50 then "26-50 logins"
        else "51+ logins"
        end
        @login_frequency[bucket] += 1
      end

      # Top users by login count in this period (non-staff)
      @top_users_by_logins = login_events
        .joins("INNER JOIN users ON users.id = ahoy_events.user_id")
        .where(users: { super_user: false })
        .group(Arel.sql("CONCAT(users.first_name, ' ', users.last_name)"))
        .count
        .sort_by { |_k, v| -v }
        .first(10).to_h
    end

    def prepare_content_creation_data
      idea_classes = [ WorkshopIdea, StoryIdea, WorkshopVariationIdea ]

      @ideas_submitted = idea_classes.sum(&:count)

      @ideas_promoted = idea_classes.sum do |klass|
        case klass.name
        when "WorkshopIdea" then klass.joins(:workshops).distinct.count
        when "StoryIdea" then klass.joins(:stories).distinct.count
        when "WorkshopVariationIdea" then klass.joins(:workshop_variations).distinct.count
        end
      end

      creator_count = idea_classes.flat_map { |k| k.distinct.pluck(:created_by_id) }.uniq.compact.size
      @avg_ideas_per_person = creator_count > 0 ? (@ideas_submitted.to_f / creator_count).round(1) : 0
    end

    def creation_velocity_data
      all_models = %w[workshop_idea story_idea workshop_variation_idea workshop_variation workshop_log quote bookmark resource community_news event video_recording]

      base_scope = scoped_events
                     .where("name LIKE 'create.%'")
                     .where(resource_type: all_models.map(&:classify))

      counts = base_scope.group(:name).count

      promoted_counts = {
        "workshop_idea" => WorkshopIdea.joins(:workshops).distinct.count,
        "story_idea" => StoryIdea.joins(:stories).distinct.count,
        "workshop_variation_idea" => WorkshopVariationIdea.joins(:workshop_variations).distinct.count
      }

      # User-generated
      user_models = %w[bookmark quote story_idea workshop_idea workshop_variation_idea workshop_log]
      user_labels = {
        "workshop_variation_idea" => "Variation Ideas"
      }
      @user_generated_content = user_models.map do |model|
        label = user_labels[model] || model.humanize.titleize.pluralize
        [ label, counts["create.#{model}"] || 0, promoted_counts[model] ]
      end

      # Admin-generated
      admin_models = %w[bookmark quote story workshop workshop_variation]
      admin_labels = {
        "workshop_variation" => "Variations"
      }
      @admin_generated_content = admin_models.map do |model|
        count = counts["create.#{model}"] || 0
        promoted = promoted_counts["#{model}_idea"]
        label = admin_labels[model] || model.humanize.titleize.pluralize
        [ label, count, promoted ]
      end
      @admin_generated_content << [ :spacer ]
      %w[resource community_news event video_recording].each do |model|
        @admin_generated_content << [ model.humanize.titleize.pluralize, counts["create.#{model}"] || 0, nil ]
      end

      # Total: combined paired types
      @total_generated_content = []
      %w[bookmark quote].each do |model|
        count = counts["create.#{model}"] || 0
        @total_generated_content << [ model.humanize.titleize.pluralize, count, nil, nil ]
      end
      pairs = [
        [ "Stories", "story", "story_idea" ],
        [ "Workshops", "workshop", "workshop_idea" ],
        [ "Variations", "workshop_variation", "workshop_variation_idea" ]
      ]
      pairs.each do |label, admin_key, idea_key|
        admin_count = counts["create.#{admin_key}"] || 0
        idea_count = counts["create.#{idea_key}"] || 0
        promoted = [ promoted_counts[idea_key] || 0, admin_count, idea_count ].min
        total = admin_count + idea_count - promoted
        @total_generated_content << [ label, total, idea_count, admin_count, promoted ]
      end
      @total_generated_content << [ "Workshop Logs", counts["create.workshop_log"] || 0, nil, nil ]
      %w[resource community_news event video_recording].each do |model|
        @total_generated_content << [ model.humanize.titleize.pluralize, counts["create.#{model}"] || 0, nil, nil ]
      end
    end

    def selected_audiences
      @selected_audiences ||= Array(params[:audience]).reject(&:blank?).presence || %w[visitors users]
    end

    def scoped_visits
      scope = Ahoy::Visit.all
      scope = scope.where(started_at: time_range) if time_range
      apply_audience_filter(scope)
    end

    def scoped_events
      scope = Ahoy::Event.all
      scope = scope.where(time: time_range) if time_range
      apply_audience_filter(scope)
    end

    def apply_audience_filter(scope)
      audiences = selected_audiences
      return scope if (audiences & %w[visitors users staff]).size == 3

      allowed_user_ids = []
      allowed_user_ids << nil if audiences.include?("visitors")

      if audiences.include?("users")
        allowed_user_ids.concat(User.where(super_user: false).pluck(:id))
      end

      if audiences.include?("staff")
        allowed_user_ids.concat(User.where(super_user: true).pluck(:id))
      end

      return scope.none if allowed_user_ids.empty?

      scope.where(user_id: allowed_user_ids)
    end

    def time_range
      period = params[:time_period].presence || "past_month"
      case period
      when "past_day"
        1.day.ago..Time.current
      when "past_week"
        1.week.ago..Time.current
      when "past_month"
        1.month.ago..Time.current
      when "past_year"
        1.year.ago..Time.current
      when "all_time"
        nil
      end
    end

    def safe_resource_path(resource_type, resource_id)
      return nil if resource_type.blank? || resource_id.blank?

      klass = resource_type.safe_constantize
      return nil unless klass && klass < ApplicationRecord

      record = klass.find_by(id: resource_id)
      record ? polymorphic_path(record) : nil
    rescue NameError, NoMethodError
      nil
    end

    def safe_json_parse(json)
      JSON.parse(json)
    rescue JSON::ParserError, TypeError
      []
    end

    # Chart.js renders array labels as multi-line; split at delimiter boundaries
    def wrap_label(text, max_chars)
      return text if text.length <= max_chars

      # Split on " + " or " → " while keeping the delimiter with the next part
      tokens = text.split(/(?<= \+ )|(?<= → )/)
      lines = []
      current = tokens.shift.to_s
      tokens.each do |token|
        if (current.length + token.length) > max_chars
          lines << current.strip
          current = token
        else
          current = "#{current}#{token}"
        end
      end
      lines << current.strip
      lines
    end

    def tracked_activity_conditions(scope)
      prefixes = %w[create update destroy view print download]

      conditions = prefixes.map { |p| scope.arel_table[:name].matches("#{p}.%") }
      conditions.inject { |memo, cond| memo.or(cond) }
    end
  end
end

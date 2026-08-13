class StoryIdeasController < ApplicationController
  include TagAssignable, StoryIdeaFormVariables
  before_action :set_story_idea, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(StoryIdea.includes(:windows_type, :organization, :workshop, :created_by, :updated_by))
    filtered = base_scope.search_by_params(params)
    @story_ideas = filtered.order(created_at: :desc)
                           .paginate(page: params[:page], per_page: per_page)
                           .decorate
    @story_ideas_count = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"
    @organizations = authorized_scope(Organization.all, as: :affiliated).order(:name)
  end

  def show
    authorize! @story_idea
    @updated_by = Ahoy::Event.where(resource_type: "StoryIdea", resource_id: @story_idea.id)
                              .where("name LIKE 'update.%'")
                              .order(time: :desc)
                              .first&.user
  end

  def new
    @story_idea = StoryIdea.new
    authorize! @story_idea

    set_story_idea_form_variables
  end

  def edit
    authorize! @story_idea

    set_story_idea_form_variables
  end

  def create
    @story_idea = StoryIdea.new(story_idea_params.except(:category_ids, :sector_ids))
    @story_idea.created_by = current_user
    @story_idea.updated_by = current_user
    authorize! @story_idea

    success = false

    StoryIdea.transaction do
      if @story_idea.save
        assign_associations(@story_idea)
        NotificationServices::CreateNotification.call(
          noticeable: @story_idea,
          kind: :idea_submitted,
          recipient_role: :person,
          recipient_email: @story_idea.created_by.email,
          notification_type: 0)
        NotificationServices::CreateNotification.call(
          noticeable: @story_idea,
          kind: :idea_submitted_fyi,
          recipient_role: :admin,
          recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
          notification_type: 0)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
      Rails.logger.error "StoryIdea create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      if params[:return_to] == "story_share"
        redirect_to story_shares_path,
                    notice: "Thank you for sharing your story! Our team will review it soon."
      elsif allowed_to?(:show?, @story_idea)
        redirect_to @story_idea, notice: "StoryIdea was successfully created."
      else
        redirect_to root_path, notice: "StoryIdea was successfully created."
      end
    else
      set_story_idea_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    @story_idea.updated_by = current_user
    authorize! @story_idea

    success = false

    StoryIdea.transaction do
      @story_idea.assign_attributes(story_idea_params.except(:images, :category_ids, :sector_ids))
      attribute_comment_authorship
      stamp_new_notification_recipients
      if @story_idea.save
        assign_associations(@story_idea)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
      Rails.logger.error "StoryIdea update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      flash[:notice] = "StoryIdea was successfully updated."
      if allowed_to?(:show?, @story_idea)
        redirect_to @story_idea, status: :see_other
      else
        redirect_to root_path, status: :see_other
      end
    else
      set_story_idea_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @story_idea

    @story_idea.destroy!
    redirect_to story_ideas_path, notice: "StoryIdea was successfully destroyed."
  end

  private

  # Stamp authorship on comments edited through the story idea form: author +
  # editor on new ones, editor on existing ones whose body changed.
  def attribute_comment_authorship
    @story_idea.comments.select(&:new_record?).each do |c|
      c.created_by = current_user
      c.updated_by = current_user
    end
    @story_idea.comments.select { |c| c.persisted? && c.body_changed? }.each do |c|
      c.updated_by = current_user
    end
  end

  # Inline-logged communications are addressed to the idea's submitter.
  def stamp_new_notification_recipients
    recipient_email = @story_idea.communications_email.presence || "n/a"
    @story_idea.notifications.select(&:new_record?).each { |n| n.recipient_email = recipient_email }
  end

  def set_story_idea
    @story_idea = StoryIdea.find(params[:id])
  end

  def story_idea_params
    params.require(:story_idea).permit(
      :title, :rhino_body, :youtube_url,
      :permission_given, :author_credit_preference, :promoted_to_story,
      :windows_type_id, :organization_id, :workshop_id, :external_workshop_title,
      :created_by_id, :updated_by_id,
      category_ids: [],
      sector_ids: [],
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      notifications_attributes: [ :id, :channel, :sender_id, :email_subject, :email_body_text, :direction, :noticeable_type, :noticeable_id, :_destroy ]
    )
  end
end

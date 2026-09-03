# One newest-first feed of comments and communications. Scoped to a single person
# when `person_id` is given (everything said to or about them — the aggregated
# comments plus the communications addressed to any of their email addresses),
# and otherwise a unified index across everyone. Staff-only, since comments are
# internal notes (CommentPolicy#manage? = admin).
class CommentsAndCommunicationsController < ApplicationController
  include AhoyTracking

  def index
    authorize! Comment, to: :manage?
    authorize! Notification, to: :index?

    @person = Person.find(params[:person_id]).decorate if params[:person_id].present?

    if turbo_frame_request?
      feed = PersonCommentAndCommunicationAggregator.new(@person, params)
      @entries = feed.paginate(params[:page], 20)
      @total_count = feed.total_count
      shown = @entries.total_entries
      @count_display = shown == @total_count ? @total_count : "#{shown}/#{@total_count}"
      render :comments_and_communications_results
    else
      feed = PersonCommentAndCommunicationAggregator.new(@person)
      @total_count = feed.total_count
      @flagged_count = feed.flagged_count
      if @person
        @new_comment = Comment.new
        @new_notification = Notification.new
        @record_targets = helpers.person_record_targets(@person)
      end
      track_view("person_comments_and_communications", { person_id: @person&.id })
    end
  end

  # The composers for the everyone feed, loaded into a Turbo frame once a person
  # is picked — the same add-a-note / log-a-communication controls the person feed
  # renders inline, now scoped to the chosen person and their filing targets.
  def composers
    authorize! Comment, to: :manage?
    authorize! Notification, to: :index?

    @person = Person.find(params[:person_id]).decorate if params[:person_id].present?
    @new_comment = Comment.new
    @new_notification = Notification.new
    @record_targets = @person ? helpers.person_record_targets(@person) : []
  end
end

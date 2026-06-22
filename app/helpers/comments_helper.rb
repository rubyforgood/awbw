module CommentsHelper
  # One-line description of what a record's related-comments overview pulls in,
  # mirroring the logic in RelatedComments.
  def related_comments_summary(commentable)
    case commentable
    when EventRegistration then "Includes the registrant, their user account, and active organizations."
    when Person then "Includes their user account and active organizations."
    when Organization then "Includes people with an active affiliation."
    when User then "Includes the linked person and their active organizations."
    when Workshop then "Includes the workshop's creator and their organizations."
    else "Comments on this record."
    end
  end

  # Maps a comment's polymorphic commentable to the label, name, link, and badge
  # styling used in the "About" column of the full-page comments index.
  def comment_subject(commentable)
    case commentable
    when EventRegistration
      { type: "Registration", name: commentable.event&.title || "Registration",
        path: edit_event_registration_path(commentable), badge: "bg-blue-100 text-blue-800" }
    when Person
      { type: "Person", name: commentable.full_name,
        path: person_path(commentable), badge: "bg-green-100 text-green-800" }
    when Organization
      { type: "Organization", name: commentable.name,
        path: organization_path(commentable), badge: "bg-purple-100 text-purple-800" }
    when User
      { type: "User account", name: commentable.person&.name || commentable.name.presence || commentable.email,
        path: user_path(commentable), badge: "bg-amber-100 text-amber-800" }
    when Workshop
      { type: "Workshop", name: commentable.try(:title).presence || commentable.try(:name) || "Workshop",
        path: edit_workshop_path(commentable), badge: "bg-rose-100 text-rose-800" }
    else
      { type: commentable.class.name, name: commentable.try(:name) || "##{commentable.id}",
        path: nil, badge: "bg-gray-100 text-gray-800" }
    end
  end
end

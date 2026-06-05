class GalleryAsset < Asset
  # Only gallery assets whose attached file is an image. Joins the blob so the
  # gallery can be searched/filtered in SQL and used as an image database.
  scope :images, -> {
    joins(file_attachment: :blob)
      .where("active_storage_blobs.content_type LIKE ?", "image/%")
  }

  # Free-text search across the editable title, the owning record type, and the
  # original filename — the metadata the team tags images with (org, workshop, etc.).
  scope :search_metadata, ->(query) {
    next all if query.blank?

    term = "%#{sanitize_sql_like(query)}%"
    where(
      "assets.title LIKE :term OR assets.owner_type LIKE :term OR active_storage_blobs.filename LIKE :term",
      term: term
    )
  }
end

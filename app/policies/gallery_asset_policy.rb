class GalleryAssetPolicy < ApplicationPolicy
  # The gallery image database is an internal admin tool for tagging and finding images.
  def index?  = admin?
  def update? = admin?

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end
end

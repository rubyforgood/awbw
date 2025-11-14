class Ckeditor::AttachmentFile < ApplicationRecord # Ckeditor::Asset
  has_one_attached :data
  validates :data, size: {less_than: 100.megabytes}, attached: true

  def url_thumb
    @url_thumb ||= nil # Ckeditor::Utils.filethumb(filename)
  end
end

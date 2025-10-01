class Ckeditor::Picture < ApplicationRecord # Ckeditor::Asset
  # has_attached_file :data,
  #                   :url  => "/ckeditor_assets/pictures/:id/:style_:basename.:extension",
  #                   :path => "/ckeditor_assets/pictures/:id/:style_:basename.:extension",
  #                   :styles => { :content => '800>', :thumb => '118x100#' }
  #
  # validates_attachment_presence :data
  # validates_attachment_size :data, :less_than => 2.megabytes
  # validates_attachment_content_type :data, :content_type => /\Aimage/

  def url_content
    url(:content)
  end

  def url(param)
    return super if actual_url.nil?

    if param == :content
      return actual_url
    else
      actual_url.gsub("/original", "/thumb")
    end

  end
end

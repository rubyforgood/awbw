# lib/rails_admin/duplicate.rb

module RailsAdmin
  module Config
    module Actions
      class Duplicate < RailsAdmin::Config::Actions::Base
        # This ensures the action only shows up for workshop
        register_instance_option :visible? do
          authorized? && bindings[:object].class == Workshop
        end

        register_instance_option :member do
          true
        end
        register_instance_option :link_icon do
          'icon-file'
        end
        # You may or may not want pjax for your action
        register_instance_option :pjax? do
          false
        end
        register_instance_option :http_methods do
          [:get, :post]
        end
        register_instance_option :controller do
          Proc.new do
            if request.post?
              @workshop = Workshop.new(@object.attributes.except("id", "created_at", "updated_at"))

              @object.categories.each do |category|
                @workshop.categories = @object.categories
              end

              @object.quotes.each do |quote|
                @workshop.quotes << quote.dup
              end

              @object.images.each do |image|
                @workshop.images << image.dup
              end


              @object.workshop_variations.each do |wv|
                @workshop.workshop_variations << wv.dup
              end

              @workshop.save
              @images_copied = @workshop.images

              @object.images.each do |image|
                image_to_copy = @images_copied.where(:file_file_name => image.file_file_name ).first

                if !image_to_copy.nil?
                   image.file.s3_object.copy_to(image_to_copy.file.s3_object, {acl: :public_read})
                   image_to_copy.file.reprocess! :thumb
                end
              end

              if !@object.thumbnail.path.nil?
                @object.thumbnail.s3_object.copy_to(@workshop.thumbnail.s3_object, {acl: :public_read})
              end
              if !@object.header.path.nil?
                @object.header.s3_object.copy_to(@workshop.header.s3_object, {acl: :public_read})
              end

              redirect_to back_or_index
              flash[:success] = "The Workshop has been duplicated: #{@object.title}."
            end
          end
        end
      end
    end
  end
end

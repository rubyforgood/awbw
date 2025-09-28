require "rails/generators/named_base"

class StimulusGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def copy_view_files
    @attribute = stimulus_attribute_value(controller_name)
    template "controller.js", "app/frontend/javascript/controllers/#{controller_name}_controller.js"

    update_index_js
  end

  private

  def controller_name
    name.underscore.gsub(/_controller$/, "")
  end

  def stimulus_attribute_value(controller_name)
    controller_name.gsub("/", "--").tr("_", "-")
  end

  def update_index_js
    controllers_path = Rails.root.join("app/frontend/javascript/controllers")
    index_file = controllers_path.join("index.js")

    import_line = "import #{controller_name.camelize}Controller from \"./#{controller_name}_controller\""
    register_line = "application.register(\"#{controller_name}\", #{controller_name.camelize}Controller)"

    # Avoid duplicate entries
    content = File.read(index_file)
    unless content.include?(import_line)
      File.open(index_file, "a") do |f|
        f.puts "\n#{import_line}"
        f.puts register_line
      end
    end
  end
end

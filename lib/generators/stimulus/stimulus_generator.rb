require "rails/generators/named_base"
require "fileutils"

class StimulusGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def copy_controller_file
    controllers_path = Rails.root.join("app/frontend/javascript/controllers")
    full_path = controllers_path.join("#{controller_name}_controller.js")

    FileUtils.mkdir_p(File.dirname(full_path))

    # Set attribute for template
    @attribute = stimulus_identifier

    template "controller.js", full_path
    update_index_js
  end

  private

  def controller_name
    name.underscore.gsub(/_controller$/, "")
  end

  def stimulus_identifier
    controller_name.gsub("/", "--").tr("_", "-")
  end

  def controller_class_name
    controller_name.split("/").map(&:camelize).join
  end

  def update_index_js
    controllers_path = Rails.root.join("app/frontend/javascript/controllers")
    index_file = controllers_path.join("index.js")

    unless File.exist?(index_file)
      File.write(index_file, "// Auto-generated Stimulus controller index\nimport { application } from \"../application\"\n\n")
    end

    import_line = "import #{controller_class_name}Controller from \"./#{controller_name}_controller\""
    register_line = "application.register(\"#{stimulus_identifier}\", #{controller_class_name}Controller)"

    content = File.read(index_file)

    unless content.include?(import_line)
      File.open(index_file, "a") do |f|
        f.puts "\n#{import_line}"
        f.puts register_line
      end
    end
  end
end

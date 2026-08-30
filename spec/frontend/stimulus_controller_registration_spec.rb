require "rails_helper"

# Controllers are registered by hand in controllers/index.js. A file that isn't
# listed there loads fine, renders its markup, and silently does nothing — the
# page looks right and no test fails. This closes that gap.
RSpec.describe "Stimulus controller registration" do
  controllers_dir = Rails.root.join("app/frontend/javascript/controllers")
  index = controllers_dir.join("index.js").read

  files = Dir.children(controllers_dir)
    .select { |name| name.end_with?("_controller.js") }
    .sort

  it "finds controllers to check" do
    expect(files).not_to be_empty
  end

  files.each do |file|
    identifier = file.delete_suffix("_controller.js").tr("_", "-")

    it "registers #{identifier} from #{file}" do
      expect(index).to include("from \"./#{file.delete_suffix('.js')}\""),
                       "#{file} is never imported in controllers/index.js"
      expect(index).to include("application.register(\"#{identifier}\","),
                       "#{file} is imported but never registered as \"#{identifier}\", so it will never run"
    end
  end
end

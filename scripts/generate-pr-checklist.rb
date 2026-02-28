#!/usr/bin/env ruby
# Generate a dynamic testing checklist based on PR changes
# Usage: ruby scripts/generate-pr-checklist.rb <base-branch> <head-branch>

base_branch = ARGV[0] || 'main'
head_branch = ARGV[1] || 'HEAD'

# Get the list of changed files
changed_files = `git diff --name-only #{base_branch}...#{head_branch}`.split("\n")

puts "Analyzing #{changed_files.length} changed files..."

# Track what was changed
has_forms = false
has_views = false
has_controllers = false
has_js = false
has_models = false
has_decorators = false
has_styles = false
has_api = false

changed_files.each do |file|
  has_forms ||= file.include?('_form.html.erb')
  has_views ||= file.include?('.html.erb') && !file.include?('_form')
  has_controllers ||= file.include?('app/controllers/')
  has_js ||= file.include?('app/frontend/') || file.include?('.js')
  has_models ||= file.include?('app/models/')
  has_decorators ||= file.include?('app/decorators/')
  has_styles ||= file.include?('app/views/') && (file.include?('.css') || file.include?('tailwind'))
  has_api ||= file.include?('app/serializers/') || file.include?('config/routes')
end

checklist = []

# Desktop/Mobile basics
checklist << '- [ ] Feature/change works on desktop view'
checklist << '- [ ] Feature/change works on mobile/tablet view'

# Form testing
if has_forms
  checklist << '- [ ] Form fields are properly labeled'
  checklist << '- [ ] Form submission works correctly'
  checklist << '- [ ] Form validation displays error messages'
  checklist << '- [ ] Form reset/clear works (if applicable)'
  checklist << '- [ ] Form preserves values on validation error'
  checklist << '- [ ] Buttons are styled consistently'
end

# View/Display testing
if has_views || has_decorators
  checklist << '- [ ] Page displays all content correctly'
  checklist << '- [ ] No missing or broken elements'
  checklist << '- [ ] Text and formatting are readable'
  checklist << '- [ ] Images load correctly'
  checklist << '- [ ] Links are functional'
end

# JavaScript/Interactivity testing
if has_js
  checklist << '- [ ] Interactive features work as expected'
  checklist << '- [ ] No console errors or warnings'
  checklist << '- [ ] No infinite loops or performance issues'
  checklist << '- [ ] Event listeners are properly attached'
  checklist << '- [ ] State management updates correctly'
end

# Controller/API testing
if has_controllers || has_api
  checklist << '- [ ] API endpoints return correct responses'
  checklist << '- [ ] Error handling displays appropriate messages'
  checklist << '- [ ] Pagination works (if applicable)'
  checklist << '- [ ] Search/filtering works (if applicable)'
  checklist << '- [ ] Authorization checks work'
end

# Model/Data testing
if has_models
  checklist << '- [ ] Data is saved correctly'
  checklist << '- [ ] Relationships are maintained'
  checklist << '- [ ] Validations work as expected'
end

# Styling/Layout testing
if has_styles
  checklist << '- [ ] Styling is consistent with design system'
  checklist << '- [ ] Colors and spacing match mockups'
  checklist << '- [ ] Responsive behavior is correct'
  checklist << '- [ ] No visual regressions'
end

# Universal checks
checklist << '- [ ] Accessibility maintained (keyboard nav, screen readers)'
checklist << '- [ ] No console errors or warnings'
checklist << '- [ ] Performance is acceptable'

puts "\n## UI Testing Checklist\n\n"
puts checklist.join("\n")

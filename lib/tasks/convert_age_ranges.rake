# frozen_string_literal: true

namespace :data do
  desc "Convert workshop age_range/age_range_spanish free-text into AgeRange categorizable_items"
  task convert_age_ranges: :environment do
    age_range_type = CategoryType.find_by!(name: "AgeRange")
    all_categories = age_range_type.categories.to_a
    categories = all_categories.index_by { |c| c.name.downcase }

    cat_3_5    = categories["3-5"]
    cat_6_12   = categories["6-12"]
    cat_13_17  = categories["13-17"]
    cat_18     = categories["18+"]
    cat_mixed  = categories["mixed-age groups"]
    cat_family = categories["family windows"]

    unless [ cat_3_5, cat_6_12, cat_13_17, cat_18, cat_mixed, cat_family ].all?
      abort "Missing AgeRange categories. Run seeds first. Need: 3-5, 6-12, 13-17, 18+, Mixed-age groups, Family windows"
    end

    # Normalize free-text to plain lowercase string
    normalize = lambda do |raw|
      return nil if raw.blank?

      text = raw.strip
      text = CGI.unescapeHTML(text)         # &ntilde; -> ñ etc.
      text = text.gsub(/<[^>]+>/, "")       # strip HTML tags
      text = text.gsub(/\r\n|\r|\n/, " ")   # collapse newlines
      text = text.strip.squeeze(" ")
      text.downcase.presence
    end

    # Map a normalized age_range string to one or more Category records.
    classify = lambda do |raw|
      text = normalize.call(raw)
      return [] if text.nil? || %w[0 x n/a].include?(text) || text.match?(/\A[\s\r\n]*\z/)

      # Extract numeric bounds if present (e.g. "5-12", "6 and up", "10+")
      low = nil
      high = nil

      if text =~ /(\d+)\s*[-–—]\s*(\d+)/
        low = $1.to_i
        high = $2.to_i
      elsif text =~ /(\d+)\s*(?:to|a)\s+(\d+)/
        low = $1.to_i
        high = $2.to_i
      elsif text =~ /(\d+)\s*[-–—]\s*(?:above|however)/
        low = $1.to_i
        high = 99
      elsif text =~ /(\d+)\s*(\+|and\s*(up|above|older)|&\s*up|years? old on up)/
        low = $1.to_i
        high = 99
      elsif text =~ /(\d+)\s*(?:en adelante|para arriba|y (?:más|mas|hasta|mayores))/
        low = $1.to_i
        high = 99
      elsif text =~ /(\d+)\s*(?:o más|o mas)/
        low = $1.to_i
        high = 99
      elsif text =~ /(\d+)\s*up\b/
        low = $1.to_i
        high = 99
      elsif text =~ /(\d+)\s*(?:años? en adelante|años? y mayores)/
        low = $1.to_i
        high = 99
      elsif text =~ /\b(\d{1,2})\s*(?:years?\s*old|años|year\s*olds?|yr\s*olds?)\b/
        # Standalone age: "5 years old", "10 años"
        low = $1.to_i
        high = low
      elsif text =~ /\A(\d{1,2})\z/
        # Bare number: "5", "12"
        low = $1.to_i
        high = low
      end

      # Keyword-based detection
      has_adult = text.match?(/\badult|women|18\s*\+|18 and (up|older)/i)
      has_teen  = text.match?(/\bteen|tween|13\s*[-–&]\s*(18|19|up)|14-17|13\/18/i)
      has_child = text.match?(/\bchild|elementary|school\s*age/i)
      has_preschool = text.match?(/\bpreschool|pre-school|prek|pre-k|kinder/i)
      has_all   = text.match?(/\ball\s*age|\bany\s*age|\bany\b|\ball\b|\bmixed|family|todas\s*las\s*edades/i)
      has_youth = text.match?(/\byouth|young\s*people|jóvenes|jovenes/i)

      result = Set.new

      result << cat_mixed if has_all

      if has_adult && !low
        result << cat_18
      end

      if has_teen && !low
        result << cat_13_17
      end

      if has_child && !low
        result << cat_6_12
        result << cat_3_5
      end

      if has_preschool
        result << cat_3_5
      end

      if has_youth && !low
        result << cat_6_12
        result << cat_13_17
      end

      # Numeric range mapping — include a bucket if the input range overlaps it.
      # Bucket boundaries: 3-5, 6-12, 13-17, 18+
      if low && high
        result << cat_3_5   if low <= 5  && high >= 3
        result << cat_6_12  if low <= 12 && high >= 6
        result << cat_13_17 if low <= 17 && high >= 13
        result << cat_18    if high >= 18 || (high == 99 && low >= 18)
      end

      # "X and up" fallback if nothing matched above
      if result.empty? && low && high == 99
        result << cat_3_5   if low <= 5
        result << cat_6_12  if low <= 12
        result << cat_13_17 if low <= 17
        result << cat_18    if low <= 18
      end

      result.to_a
    end

    # Build a set of exact-match strings that should nil out the column.
    # Matches any category name (case-insensitive, stripped).
    category_names = Set.new(all_categories.map { |c| c.name.downcase })

    # Check if a raw value, once cleaned, exactly matches a category name.
    exact_match = lambda do |raw|
      text = normalize.call(raw)
      return false if text.nil?
      category_names.include?(text)
    end

    # Values that should be silently nilled out (no comment needed).
    junk_value = lambda do |raw|
      text = normalize.call(raw)
      text.nil? || %w[0 x n/a].include?(text) || text.match?(/\A[\s\r\n]*\z/)
    end

    comment_tag = "[AGE_RANGE_DATA]"

    total = 0
    skipped = 0
    already_tagged = 0
    commented = 0
    nilled_en = 0
    nilled_es = 0
    unmatched = []

    Workshop.where.not(age_range: [ nil, "" ]).or(
      Workshop.where.not(age_range_spanish: [ nil, "" ])
    ).find_each do |workshop|
      # --- Classify from both fields (union of matches) ---
      matched_from_en = classify.call(workshop.age_range)
      matched_from_es = classify.call(workshop.age_range_spanish)
      matched_categories = (matched_from_en + matched_from_es).uniq

      raw_en = workshop.age_range
      raw_es = normalize.call(workshop.age_range_spanish)
      source_parts = []
      source_parts << "age_range: '#{raw_en}'" if raw_en.present?
      source_parts << "age_range_spanish: '#{raw_es}'" if raw_es.present?
      source_label = source_parts.join(", ")

      if matched_categories.empty?
        # Silently nil out junk values (whitespace, n/a, x, 0) without commenting
        en_junk = workshop.age_range.present? && junk_value.call(workshop.age_range)
        es_junk = workshop.age_range_spanish.present? && junk_value.call(workshop.age_range_spanish)
        if (en_junk || workshop.age_range.blank?) && (es_junk || workshop.age_range_spanish.blank?)
          junk_updates = {}
          junk_updates[:age_range] = nil if en_junk
          junk_updates[:age_range_spanish] = nil if es_junk
          workshop.update_columns(junk_updates) if junk_updates.any?
          skipped += 1
          next
        end

        unmatched << { id: workshop.id, age_range: raw_en, age_range_spanish: raw_es }
        skipped += 1

        # Leave a comment so staff can manually review
        workshop.comments.create!(
          body: "#{comment_tag} Could not auto-apply age range categories from #{source_label}. Please review and assign manually."
        )
        commented += 1
      else
        # Skip categories already assigned
        existing_ids = workshop.categorizable_items
                               .joins(:category)
                               .where(categories: { category_type_id: age_range_type.id })
                               .pluck(:category_id)

        new_categories = matched_categories.reject { |c| existing_ids.include?(c.id) }

        if new_categories.empty?
          already_tagged += 1
        else
          new_categories.each do |cat|
            workshop.categorizable_items.create!(category: cat)
          end

          applied_names = new_categories.map(&:name).join(", ")
          workshop.comments.create!(
            body: "#{comment_tag} Auto-applied age range categories: #{applied_names} from #{source_label}."
          )
          commented += 1
          total += 1
        end
      end

      # --- Nil out columns that exactly match a category name or are junk ---
      updates = {}
      if workshop.age_range.present? && (exact_match.call(workshop.age_range) || junk_value.call(workshop.age_range))
        updates[:age_range] = nil
        nilled_en += 1
      end
      if workshop.age_range_spanish.present? && (exact_match.call(workshop.age_range_spanish) || junk_value.call(workshop.age_range_spanish))
        updates[:age_range_spanish] = nil
        nilled_es += 1
      end
      workshop.update_columns(updates) if updates.any?
    end

    puts "Done! Tagged #{total} workshops."
    puts "Comments created: #{commented}" if commented > 0
    puts "Already tagged: #{already_tagged}" if already_tagged > 0
    puts "Skipped (unmatched): #{skipped}" if skipped > 0
    puts "Nilled age_range: #{nilled_en}" if nilled_en > 0
    puts "Nilled age_range_spanish: #{nilled_es}" if nilled_es > 0
    if unmatched.any?
      puts "\nUnmatched values (#{unmatched.size}):"
      unmatched.each do |u|
        puts "  Workshop ##{u[:id]}: en=#{u[:age_range].inspect} es=#{u[:age_range_spanish].inspect}"
      end
    end
  end
end

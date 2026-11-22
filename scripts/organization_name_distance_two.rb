# One-off: organization names two single-character edits apart.
#
# The deduper only lists names one edit apart (typos it can trust). This prints the
# pairs two edits apart, which it deliberately leaves out, so staff can fix a name
# and let the queue pick the pair up. Read-only; prints to stdout.
#
#   bin/rails runner scripts/organization_name_distance_two.rb
#   bin/rails runner scripts/organization_name_distance_two.rb > /tmp/far_pairs.txt

finder = OrganizationServices::DuplicateFinder
orgs = Organization.select(:id, :name, :filemaker_code).order(:id).to_a
keys = orgs.to_h { |org| [ org.id, finder.tokens(org.name).join(" ") ] }

def edit_distance(left, right, cap)
  return 99 if (left.length - right.length).abs > cap

  previous = (0..right.length).to_a
  left.each_char.with_index do |from, row|
    current = [ row + 1 ]
    right.each_char.with_index do |to, column|
      current << [ previous[column + 1] + 1, current[column] + 1, previous[column] + (from == to ? 0 : 1) ].min
    end
    return 99 if current.min > cap

    previous = current
  end
  previous.last
end

buckets = Hash.new { |hash, key| hash[key] = [] }
orgs.each do |org|
  key = keys[org.id]
  next if key.length < 6

  buckets[[ key[0], key[-1] ]] << [ org, key ]
end

pairs = buckets.each_value.flat_map do |entries|
  entries.combination(2).filter_map do |(left_org, left), (right_org, right)|
    next if (left.length - right.length).abs > 2

    distance = edit_distance(left, right, 2)
    [ left_org, right_org ] if distance == 2
  end
end

puts "#{pairs.size} organization-name pairs two edits apart"
pairs.each do |left, right|
  puts
  puts "  #{left.name}  [#{left.id} #{left.filemaker_code}]"
  puts "  #{right.name}  [#{right.id} #{right.filemaker_code}]"
end

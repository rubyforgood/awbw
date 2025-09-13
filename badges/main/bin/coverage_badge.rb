#!/usr/bin/env ruby
# frozen_string_literal: true
require "json"

json_path = "coverage/summary.json"
abort("Missing #{json_path} (did SimpleCov JSON run in CI?)") unless File.exist?(json_path)

data = JSON.parse(File.read(json_path))
percent = data.dig("covered_percent")
abort("Could not read covered_percent") unless percent

percent = percent.to_f.round(2)

# Pick a shields-like color ramp
color =
  case percent
  when 90..100 then "#4c1"        # brightgreen
  when 80...90 then "#97CA00"     # green
  when 70...80 then "#a4a61d"     # yellowgreen
  when 60...70 then "#dfb317"     # yellow
  when 50...60 then "#fe7d37"     # orange
  else              "#e05d44"     # red
  end

# Dynamic width for the value segment so long numbers don't clip
label = "coverage"
value = "#{percent}%"
label_w = 62
value_w = [40, (value.length * 7.2).ceil + 10].max
total_w = label_w + value_w

svg = <<~SVG
<svg xmlns="http://www.w3.org/2000/svg" width="#{total_w}" height="20" role="img" aria-label="#{label}: #{value}">
  <linearGradient id="b" x2="0" y2="100%">
    <stop offset="0" stop-color="#fff" stop-opacity=".7"/>
    <stop offset=".1" stop-color="#aaa" stop-opacity=".1"/>
    <stop offset=".9" stop-opacity=".3"/>
    <stop offset="1" stop-opacity=".5"/>
  </linearGradient>
  <mask id="a">
    <rect width="#{total_w}" height="20" rx="3" fill="#fff"/>
  </mask>
  <g mask="url(#a)">
    <rect width="#{label_w}" height="20" fill="#555"/>
    <rect x="#{label_w}" width="#{value_w}" height="20" fill="#{color}"/>
    <rect width="#{total_w}" height="20" fill="url(#b)"/>
  </g>
  <g fill="#fff" text-anchor="middle"
     font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
    <text x="#{label_w / 2}" y="15" fill="#010101" fill-opacity=".3">#{label}</text>
    <text x="#{label_w / 2}" y="14">#{label}</text>
    <text x="#{label_w + value_w / 2}" y="15" fill="#010101" fill-opacity=".3">#{value}</text>
    <text x="#{label_w + value_w / 2}" y="14">#{value}</text>
  </g>
</svg>
SVG

File.write("tmp/coverage_badge.svg", svg)
puts "Generated coverage_badge.svg (#{percent}%)"

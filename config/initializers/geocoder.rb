Geocoder.configure(
  lookup: :maxmind_local,
  maxmind_local: {
    file: Rails.root.join("db/geoip/GeoLite2-City.mmdb")
  }
)

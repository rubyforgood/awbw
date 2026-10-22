# Dev-only staff aliases - run on their own via `rake db:seed:staff_aliases`, or as part
# of `rake db:seed:dev`. The real list pairs real names with real accounts and is loaded
# from outside the repo (`data:load_staff_aliases`), so these are invented staff in the
# same shapes the archive holds: one person typed many ways, a first name on its own, a
# lowercase login, a role suffix, two people in one field, a name plus a title, an email
# where a name belongs, a staffer whose surname changed, and a shared login that means
# no one.
#
# The three names db/seeds/dev/fm_archive.rb stamps on its rows (mbrown, jlee, admin) are
# recorded too, so the dev archive's EnteredBy/ModifiedBy resolve the way the real one does.

puts "Creating dev staff aliases…"

admin = User.find_by!(email: "umberto.user@example.com")

# Each staffer is one portal account; the archive knows them by every name below.
staff = {
  "dana.whitfield@example.com" => {
    name: [ "Dana", "Whitfield" ],
    aliases: [ "Dana", "Dana R Whitfield", "Dana Whitfield", "Dana Whitfield & Priya Raman",
               "Dana Whitfield, Priya Raman", "Dana Whitfield, Executive Director", "mbrown" ]
  },
  "priya.raman@example.com" => {
    name: [ "Priya", "Raman" ],
    aliases: [ "Priya Raman", "Priya Raman WORK", "priya", "jlee" ]
  },
  "noor.hassan@example.com" => {
    name: [ "Noor", "Hassan" ],
    aliases: [ "Noor Hassan", "noor", "noor!", "noorhassan" ]
  },
  "rosa.okonkwo@example.com" => {
    name: [ "Rosa", "Okonkwo" ],
    # The archive sometimes holds an address where a name belongs.
    aliases: [ "Rosa Okonkwo", "r.okonkwo.personal@example.com" ]
  },
  "tomas.baptiste@example.com" => {
    name: [ "Tomas", "Baptiste" ],
    # A staffer the archive knew under both surnames, and under both at once.
    aliases: [ "Tomas Baptiste", "Tomas Oyelaran", "Tomas Oyelaran Baptiste" ]
  }
}

staff.each do |email, details|
  first_name, last_name = details[:name]
  user = User.find_or_create_by!(email: email) do |record|
    record.password = "password"
    record.super_user = false
    record.confirmed_at = Time.current
  end

  unless user.person
    person = Person.create!(first_name:, last_name:, email:, created_by: admin, updated_by: admin)
    user.update!(person: person)
  end

  details[:aliases].each do |name|
    StaffAlias.find_or_initialize_by(name: name).update!(user: user, ignored: false)
  end
end

# A login several people shared says who entered a row no more precisely than "someone at
# AWBW", so it names no one on purpose and stays out of the undecided names.
[ "Staff", "Volunteer", "Database Admin" ].each do |name|
  StaffAlias.find_or_initialize_by(name: name).update!(user: nil, ignored: true)
end

StaffAlias.find_or_initialize_by(name: "admin").update!(user: admin, ignored: false)

# The shared account a row is credited to when its staff name resolves to no one.
awbw_staff = User.find_or_create_by!(email: User::AWBW_STAFF_EMAIL) do |record|
  record.password = "password"
  record.super_user = false
  record.confirmed_at = Time.current
end
unless awbw_staff.person
  person = Person.create!(first_name: "AWBW", last_name: "Staff", email: User::AWBW_STAFF_EMAIL, created_by: admin, updated_by: admin)
  awbw_staff.update!(person: person)
end

puts "  #{StaffAlias.resolving.count} staff names resolve, #{StaffAlias.ignored.count} name no one"

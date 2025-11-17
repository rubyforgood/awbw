namespace :db do
  namespace :seed do

    desc 'Import Legacy Data'
    task :import_legacy_data => :environment do |task, arguments|
      [
        :create_defaults, :import_workshops, :import_categories,
        :import_workshop_categories, :import_users, :import_projects,
        :import_project_users, :import_faqs, :import_quotes,
        :import_workshop_quotes, :import_workshop_variations,
        :import_leader_spotlights, :import_workshop_leader_spotlights,
        :import_workshop_favorites, :import_user_permissions
      ].each do |task|
        Rake::Task["db:seed:#{task}"].invoke
      end
    end

    desc 'Create Defaults'
    task :create_defaults => :environment do
      ProjectObligation.create_defaults
      ProjectStatus.create_defaults
      WindowsType.create_defaults
      Sector.create_defaults
    end

    desc 'Import Legacy Users'
    task :import_users => :environment do
      CSV.foreach(full_filepath('users.csv'), headers: true) do |row|
        create_user(row)
      end
    end

    desc 'Import Project Users'
    task :import_project_users => :environment do
      xml = open_as_xml(full_filepath('project_users.xml'))
      process_xml_rows(xml, :create_project_user)
    end

    desc 'Import Legacy Workshops'
    task :import_workshops => :environment do |task, arguments|
      xml = open_as_xml(full_filepath('workshops.xml'))
      process_xml_rows(xml, :create_workshop)
    end

    desc 'Import Categories'
    task :import_categories => :environment do |task, arguments|
      categories_filepaths.each do |metadatum_name, filepath|
        xml = open_as_xml(full_filepath(filepath))
        process_xml_rows(xml, :create_category, metadatum_name)
      end
    end

    desc 'Import Workshop Categories'
    task :import_workshop_categories => :environment do |task, args|
      categories_filepaths.each do |metadatum_name, filepath|
        xml = open_as_xml(full_filepath("workshop_#{filepath}"))
        process_xml_rows(xml, :create_workshop_category, metadatum_name)
      end
    end

    desc 'Import projects'
    task :import_projects => :environment do |task, args|
      CSV.foreach(full_filepath('projects.csv'), headers: true) do |row|
        next unless row['str_name']
        create_project(row)
      end
    end

    desc 'Import quotes'
    task :import_quotes => :environment do
      CSV.foreach(full_filepath('quotes.csv'), headers: true) do |row|
        create_quote(row)
      end
    end

    desc 'Import workshop quotes'
    task :import_workshop_quotes => :environment do
      xml = open_as_xml(full_filepath('workshop_quotes.xml'))
      process_xml_rows(xml, :create_workshop_quote)
    end

    desc 'import faqs'
    task :import_faqs => :environment do
      xml = open_as_xml(full_filepath('faq.xml'))
      process_xml_rows(xml, :create_faq)
    end

    desc 'import workshop variations'
    task :import_workshop_variations => :environment do
      xml = open_as_xml(full_filepath('workshop_variations.xml'))
      process_xml_rows(xml, :create_workshop_variation)
    end

    desc 'import leader spotlights'
    task :import_leader_spotlights => :environment do
      xml = open_as_xml(full_filepath('leader_spotlights.xml'))
      process_xml_rows(xml, :create_leader_spotlight)
    end

    desc 'import workshop leader spotlights'
    task :import_workshop_leader_spotlights => :environment do
      xml = open_as_xml(full_filepath('workshop_leader_spotlights.xml'))
      process_xml_rows(xml, :create_workshop_leader_spotlight)
    end

    desc 'import workshop favorites'
    task :import_workshop_favorites => :environment do
      CSV.foreach(full_filepath('workshop_favorites.csv'), headers: true) do |row|
        create_workshop_favorite(row)
      end
    end

    desc 'import legacy workshop images'
    task :import_workshop_images => :environment do
      Workshop.legacy.each do |workshop|
        workshop.images.destroy_all
        images = Nokogiri::HTML(workshop.objective).css('img')
        images.to_a.each do |image|
          begin
            pathname = image.attributes['src'].value
            next if pathname.include?('transparent') || pathname.include?('https') #yields error
            uri = pathname.include?('http') ? pathname : "http://awbw.org#{pathname}"
            workshop.images.create(file: open(uri))
          rescue OpenURI::HTTPError => e
          end
        end
      end
    end
  end
end

private

def create_project_user(xml, _name = nil)
  user = User.find_by_legacy_id(search_for_value(xml, 'userid'))
  project = Project.find_by_legacy_id(search_for_value(xml, 'projectid'))
  return unless user && project
  ProjectUser.find_or_create_by(
    user: user,
    project: project,
    position: search_for_value(xml, 'num_position'),
    filemaker_code: search_for_value(xml, 'str_filemakercode')
  )
end

def create_project(project)
  ProjectStatus.create_defaults unless ProjectStatus.any?
  start_date = project['dte_start'] unless project['dte_start'] == '0000-00-00'
  end_date = project['dte_end'] unless project['dte_end'] == '0000-00-00'
  window_id = project['windowstypeid'].to_i

  if (1..3).include?(window_id)
    windows_type_id = windows_type_id(project['windowstypeid'])
  end
  project = Project.find_or_create_by(
    legacy_id: project['id'],
    name: project['str_name'].slice(0, 255),
    windows_type_id: windows_type_id,
    start_date: start_date,
    end_date: end_date,
    locality: project['str_locality'],
    description: project['txt_description'],
    notes: project['txt_notes'],
    filemaker_code: project['str_filemakercode'],
    inactive: project['bln_inactive'],
    legacy: true,
    project_status_id: project['statusid']
  )
end

def categories_filepaths
  {
    'ArtType' => 'art_types.xml',
    'AgeRange' => 'age_ranges.xml',
    'EmotionalTheme' => 'emotional_themes.xml',
    'HolidayTheme' => 'holiday_themes.xml',
    'Strength' => 'strengths.xml'
  }
end

def process_xml_rows(xml, method, _name = nil)
  xml.search('Row').each do |row|
    send(method, row, _name)
  end
end

def full_filepath(filepath)
  Rails.root.join('db', 'seeds', filepath)
end

def open_as_xml(file)
  File.open(file) { |f| Nokogiri::XML(f) }
end

def create_category(xml, metadatum_name)
  Category.find_or_create_by(
    legacy_id: search_for_value(xml, 'id'),
    metadatum: Metadatum.find_or_create_by(name: metadatum_name),
    name: search_for_value(xml, 'str_name')
  )
end

def create_workshop_category(xml, metadatum_name)
  workshop = Workshop.find_by(legacy_id: search_for_value(xml, 'workshopid'))
  metadatum = Metadatum.find_by(name: metadatum_name)

  category = Category.find_by(
    metadatum: metadatum,
    legacy_id: search_for_value(
      xml, "#{metadatum_name.downcase}id"
    )
  )

  return unless workshop && category

  CategorizableItem.find_or_create_by(
    legacy_id: search_for_value(xml, 'id'),
    categorizable: workshop,
    category: category
  )
end


def create_workshop(xml, _name = nil)
  return if xml.search('str_title')[0].content == "\n delete \n"
  Workshop.find_or_create_by(
    legacy_id: search_for_value(xml, 'id'),
    title: search_for_value(xml, 'str_title'),
    author_first_name: search_for_value(xml, 'str_author_firstname'),
    author_last_name: search_for_value(xml, 'str_author_lastname'),
    author_location: search_for_value(xml, 'str_author_location'),
    windows_type_id: windows_type_id(search_for_value(xml, 'windowstypeid')),
    month: search_for_value(xml, 'num_month'),
    year: search_for_value(xml, 'num_year'),
    objective: search_for_value(xml, 'txt_code'),
    description: search_for_value(xml, 'txt_description'),
    notes: search_for_value(xml, 'txt_notes'),
    tips: search_for_value(xml, 'txt_tips'),
    pub_issue: search_for_value(xml, 'str_pub_issue'),
    misc1: search_for_value(xml, 'str_misc1'),
    misc2: search_for_value(xml, 'str_misc2'),
    filemaker_code: search_for_value(xml, 'str_filemakercode'),
    inactive: search_for_value(xml, 'bln_inactive'),
    searchable: search_for_value(xml, 'bln_searchable'),
    legacy: true,
    featured: false,
    created_at: search_for_value(xml, 'ts_create').to_datetime
  )
end

def search_for_value(xml, endpoint)
  matches = xml.search(endpoint)
  matches.any? ? matches[0].content.strip : nil
end

def create_user(row)
  return unless row['str_email'] || User.find_by_email(row['str_email'])
  user = User.new(
    legacy_id: row['id'],
    email: row['str_email'],
    first_name: row['str_firstname'],
    last_name: row['str_lastname'],
    phone: row['str_phone'],
    address: row['str_address1'],
    city: row['str_city'],
    state: row['str_state'],
    zip: row['str_zip'],
    birthday: row['dte_birthday'],
    subscribecode: row['str_subscribecode'],
    inactive: row['bln_inactive'],
    confirmed: row['bln_confirmed'],
    comment: row['txt_user_comment'],
    notes: row['txt_notes'],
    password: row['str_password'],
    legacy: true
  )
  user.save
end

def create_quote(row)
  Quote.find_or_create_by(
    quote: row['str_quote'],
    inactive: row['bln_inactive'],
    legacy_id: row['id'],
    legacy: true
  )
end

def create_workshop_quote(xml, _name = nil)
  workshop = Workshop.find_by_legacy_id(search_for_value(xml, 'workshopid'))
  quote = Quote.find_by_legacy_id(search_for_value(xml, 'quoteid'))
  return unless workshop && quote
  QuotableItemQuote.find_or_create_by(
    legacy_id: search_for_value(xml, 'id'),
    quotable: workshop,
    quote: quote
  )
end

def create_faq(xml, _name = nil)
  Faq.find_or_create_by(
    question: search_for_value(xml, 'str_question'),
    answer: search_for_value(xml, 'txt_answer'),
    ordering: search_for_value(xml, 'ordering'),
    inactive: search_for_value(xml, 'bln_inactive')
  )
end

def create_workshop_variation(xml, _name = nil)
  legacy_id = search_for_value(xml, 'workshopid')
  workshop = Workshop.find_by_legacy_id(legacy_id)

  return unless workshop
  variation = workshop.workshop_variations.find_or_create_by(
    legacy: true,
    name: search_for_value(xml, 'str_name'),
    code: search_for_value(xml, 'txt_code'),
    inactive: search_for_value(xml, 'bln_inactive'),
    ordering: search_for_value(xml, 'ordering'),
  )
end

def create_leader_spotlight(xml, _name = nil)
  leader_spotlight = LeaderSpotlight.find_or_create_by(
    title: search_for_value(xml, 'str_headline'),
    author: search_for_value(xml, 'str_name'),
    agency: search_for_value(xml, 'str_agency'),
    text: search_for_value(xml, 'txt_code'),
    ordering: search_for_value(xml, 'ordering'),
    inactive: search_for_value(xml, 'bln_inactive'),
    filemaker_code: search_for_value(xml, 'str_filemakercode'),
    windows_type_id: windows_type_id(search_for_value(xml, 'windowstypeid')),
    legacy: true,
    legacy_id: search_for_value(xml, 'id')
  )

  leader_spotlight.images.destroy_all if leader_spotlight.images.any?

  image = open("http://awbw.org#{search_for_value(xml, 'str_pic')}")
  leader_spotlight.images.create(file: image)
  rescue OpenURI::HTTPError
end

def create_workshop_leader_spotlight(xml, _name = nil)
  workshop = Workshop.find_by_legacy_id(search_for_value(xml, 'workshopid'))
  leader_spotlight = LeaderSpotlight.find_by_legacy_id(search_for_value(xml, 'leaderspotlightid'))

  return unless workshop && leader_spotlight

  WorkshopResource.find_or_create_by(
    workshop: workshop,
    resource: leader_spotlight
  )
end

def create_workshop_favorite(row)
  workshop = Workshop.find_by_legacy_id(row['workshopid'])
  user = User.find_by_legacy_id(row['userid'])

  return unless workshop && user

  workshop.led_count += 1
  workshop.save
  user.bookmarks.find_or_create_by(
    bookmarkable: workshop
  )
end

def windows_type_id(legacy_id)
  WindowsType.find_by(
    legacy_id: legacy_id
  ).id
end

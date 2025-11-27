namespace :db do
  namespace :dev do

    desc 'Import dev data'
    task :seed => :environment do |task, arguments|
      [
        :import_workshops,
        :generate_dev_seeds,
        :import_projects,
        :import_quotes,
        :import_workshop_quotes,
        :import_workshop_variations,
      ].each do |task|
        Rake::Task["db:dev:#{task}"].invoke
      end
    end

    desc 'Import workshops'
    task :import_workshops => :environment do |task, arguments|
      puts "Importing workshops…"
      xml = open_as_xml(full_filepath('workshops.xml'))
      process_xml_rows(xml, :create_workshop)
    end

    desc 'Generate dev seed data'
    task :generate_dev_seeds => :environment do |task, arguments|
      load Rails.root.join("db/seeds/dummy_dev_seeds.rb")
    end

    desc 'Import projects'
    task :import_projects => :environment do |task, args|
      puts "Importing projects…"
      CSV.foreach(full_filepath('projects.csv'), headers: true) do |row|
        next unless row['str_name']
        create_project(row)
      end
    end

    desc 'Import quotes'
    task :import_quotes => :environment do
      puts "Importing quotes…"
      CSV.foreach(full_filepath('quotes.csv'), headers: true) do |row|
        create_quote(row)
      end
    end

    desc 'Import workshop quotes'
    task :import_workshop_quotes => :environment do
      puts "Importing workshop quotes…"
      xml = open_as_xml(full_filepath('workshop_quotes.xml'))
      process_xml_rows(xml, :create_workshop_quote)
    end

    desc 'import workshop variations'
    task :import_workshop_variations => :environment do
      puts "Importing workshop variations…"
      xml = open_as_xml(full_filepath('workshop_variations.xml'))
      process_xml_rows(xml, :create_workshop_variation)
    end
  end
end

private

def create_project(project)
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
    # locality: project['str_locality'],
    description: project['txt_description'],
    notes: project['txt_notes'],
    filemaker_code: project['str_filemakercode'],
    inactive: project['bln_inactive'],
    legacy: true,
    project_status_id: project['statusid']
  )
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

def create_workshop(xml, _name = nil)
  return if xml.search('str_title')[0].content == "\n delete \n"
  first  = search_for_value(xml, 'str_author_firstname')
  last   = search_for_value(xml, 'str_author_lastname')

  full_name = [first, last].compact.map(&:strip).reject(&:blank?).join(" ")
  Workshop.find_or_create_by(
    legacy_id: search_for_value(xml, 'id'),
    title: search_for_value(xml, 'str_title'),
    full_name: full_name.presence,
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
    legacy: true,
    featured: false,
    created_at: search_for_value(xml, 'ts_create').to_datetime
  )
end

def search_for_value(xml, endpoint)
  matches = xml.search(endpoint)
  matches.any? ? matches[0].content.strip : nil
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

def windows_type_id(legacy_id)
  WindowsType.find_by(
    legacy_id: legacy_id
  ).id
end

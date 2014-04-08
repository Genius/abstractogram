class Talk < ActiveRecord::Base
  validates_presence_of :year, :title, :abstract
  validates_uniqueness_of :title, :scope => :year
  
  ALL_YEARS = (2007..2014).to_a
  
  # scraping code
  
  class << self
    def mine
      find_by_year_and_speaker(2014, "Todd Schneider")
    end
    
    def destroy_all_talks(year = nil)
      if year.present?
        where(:year => year)
      else
        all
      end.destroy_all
    end

    def create_all_talks
      ALL_YEARS.each do |year|
        send("create_railsconf_#{year}_talks")
      end
    end
    
    def fetch_and_parse(url)
      Nokogiri::HTML(RestClient.get(url))
    end
    
    def create_railsconf_2014_talks
      # 2014 RailsConf program: http://railsconf.com/program
      # local copy: /Users/me/railsconf2014.html
    end
    
    def create_railsconf_2013_talks
      talks_doc = fetch_and_parse("http://railsconf.com/2013/talks.html")
      bios_doc = fetch_and_parse("http://railsconf.com/2013/speakers.html")

      talks_doc.css(".talk").each do |elm|
        title = elm.css("h4").inner_text
        speaker = elm.css("h6 a").first.inner_text.presence
        abstract = elm.css("> p").inner_text

        bio_id = elm["id"].gsub("talk", "speaker")
        bio = bios_doc.css("##{bio_id} > p").inner_text.presence

        Talk.create(:year => 2013, :title => title, :speaker => speaker, :abstract => abstract, :bio => bio)
      end
    end
    
    def create_railsconf_2012_talks
      doc = fetch_and_parse("http://lanyrd.com/2012/railsconf/")
      
      doc.css(".session-detail").each do |elm|
        title = elm.css("h3 a").inner_text
        speaker = elm.css("> p a").map(&:inner_text).join(", ").presence
        
        next if title.blank? || speaker.blank? || title.downcase.squish.starts_with?("keynote:")
        
        talk_doc = fetch_and_parse("http://lanyrd.com#{elm.css("h3 a").first["href"]}")
        
        abstract = talk_doc.css(".abstract").inner_text
        bio = talk_doc.css(".profile-longdesc").inner_text.presence || 
              talk_doc.css(".profile-desc").inner_text.presence
        
        Talk.create(:year => 2012, :title => title, :speaker => speaker, :abstract => abstract, :bio => bio)
      end
    end
    
    (2008..2011).each do |year|
      define_method "create_railsconf_#{year}_talks" do
        create_railsconf_oreilly_talks_by_year(year)
      end
    end
    
    def create_railsconf_oreilly_talks_by_year(year)
      sessions_doc = fetch_and_parse("http://en.oreilly.com/rails#{year}/public/schedule/topic/General")
    
      sessions_doc.css(".en_session_title .url").each do |a|
        next if a.inner_text.to_s.downcase.squish == "lightning talks"
      
        doc = fetch_and_parse("http://en.oreilly.com#{a["href"]}")
      
        title = doc.css("h1.summary").inner_text
        speaker = doc.css(".en_session_speakers a").map(&:inner_text).join(", ").presence
        abstract = doc.css(".en_session_description.description").inner_text
        bio = doc.css(".en_speaker_bio.note p").inner_text.presence
      
        Talk.create(:year => year, :title => title, :speaker => speaker, :abstract => abstract, :bio => bio)
      end
    end
    
    def create_railsconf_2007_talks
      sessions_doc = fetch_and_parse("http://conferences.oreillynet.com/pub/w/51/sessions.html")
      
      sessions_doc.css(".s .summary a.url").each do |elm|
        link_text = elm.inner_text.to_s.downcase.squish
        next if link_text == "welcome" || link_text == "keynote"
        
        talk_doc = fetch_and_parse("http://conferences.oreillynet.com#{elm["href"]}")
        
        title = talk_doc.css("#session_view h2").inner_text
        speaker = talk_doc.css("#session_view > p > a").map(&:inner_text).join(", ").presence
        abstract = talk_doc.css("#session_desc").inner_text
        
        next if abstract.blank?
        
        bio = talk_doc.css("#session_view > p > a").map do |bio_link|
          bio_doc = fetch_and_parse("http://conferences.oreillynet.com#{bio_link["href"]}")
          bio_doc.css(".bio").inner_text.presence
        end.compact.join("\n")
        
        Talk.create(:year => 2007, :title => title, :speaker => speaker, :abstract => abstract, :bio => bio)
      end
    end
    
    ALL_YEARS.each do |year|
      handle_asynchronously :"create_railsconf_#{year}_talks"
    end
  end
  
  # generate ngrams code
  
  def self.redis
    $redis
  end
  
  MAX_NGRAM_SIZE = 3
  TOTAL_KEY = "abstractogram:totals"
  ALL_YEARS_KEY = "abstractogram:all_years"
  
  def ngrams(n)
    # given a value of n, calculate n-grams from a talk's abstract
  end
  
  class << self
    def generate_all_ngram_data
      ALL_YEARS.each { |y| generate_ngram_data_by_year(y) }
    end
    
    def generate_ngram_data_by_year(year)
      # iterate through all talks from a given year, calculate ngram counts and add to appropriate redis sorted set
    end
    handle_asynchronously :generate_ngram_data_by_year
  end
  
  # query ngrams code
  
  class << self
    def query(raw_term)
      # given a search term, return the number of times it appeared by year
    end
    
    def ngram_query(terms)
      terms.map do |term|
        {:name => term, :data => query(term)}
      end
    end
  end
end

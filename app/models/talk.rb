class Talk < ActiveRecord::Base
  validates_presence_of :year, :title, :abstract
  validates_uniqueness_of :title, :scope => :year
  
  # TO DO: 2006
  ALL_YEARS = (2007..2014).to_a
  
  # scraping code
  
  class << self
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
      doc = fetch_and_parse("http://railsconf.com/program")

      doc.css(".presentation .session").each do |elm|
        title = elm.css("header h1").inner_text
        speaker = elm.css("header h2").inner_text.presence
        abstract = elm.css("> p").inner_text
        bio = elm.css(".bio").inner_text.presence

        Talk.create(:year => 2014, :title => title, :speaker => speaker, :abstract => abstract, :bio => bio)
      end
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
  
  def self.sorted_set_key(year, n)
    ['abstractogram', year, n].join(":")
  end
  
  WORDS_REGEX = %r{[^[[:word:]]\s]}
  
  def ngrams(n)
    abstract.fingerprint.gsub(WORDS_REGEX, '').split(" ").each_cons(n).to_a
  end
  
  class << self
    def generate_all_ngram_data
      ALL_YEARS.each { |y| generate_ngram_data_by_year(y) }
    end
    
    def generate_ngram_data_by_year(year, opts = {})
      values_of_n = Array.wrap(opts[:n] || (1..MAX_NGRAM_SIZE).to_a)
      
      keys = values_of_n.map{ |num| sorted_set_key(year, num) }
      redis.del(*keys)
      keys.each{ |k| redis.zrem(TOTAL_KEY, k) }
      redis.zrem(ALL_YEARS_KEY, year)
      
      Talk.where(:year => year).find_each do |talk|
        values_of_n.each do |num|
          set_key = sorted_set_key(year, num)
          
          ngrams_ary = talk.ngrams(num)
          
          ngrams_ary.each do |ngram|
            redis.zincrby(set_key, 1, ngram.join(" "))
          end
          
          redis.zincrby(TOTAL_KEY, ngrams_ary.size, set_key)
        end
      end
      
      redis.zadd(ALL_YEARS_KEY, year, year)
    end
    handle_asynchronously :generate_ngram_data_by_year
  end
  
  # query ngrams code
  
  class << self
    def ngram_query(terms)
      terms.map do |term|
        {:name => term, :data => inner_query(term)}
      end
    end
    
    def inner_query(raw_term)
      term = raw_term.fingerprint
      
      n = term.split(" ").size
      years = ALL_YEARS
      counts_hsh = {}
      
      redis.pipelined do
        years.each do |year|
          key = sorted_set_key(year, n)
          
          counts_hsh[year] = redis.zscore(key, term)
        end
      end
      
      counts_hsh.sort_by { |k,v| k }.map { |ary| [ary[0], ary[1].value.to_i] }
    end
  end
end

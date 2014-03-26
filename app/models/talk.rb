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
    
    def create_railsconf_2014_talks
      html = RestClient.get("http://railsconf.com/program")
      doc = Nokogiri::HTML(html)

      doc.css(".presentation .session").each do |elm|
        title = elm.css("header h1").inner_text
        speaker = elm.css("header h2").inner_text.presence
        abstract = elm.css("> p").inner_text
        bio = elm.css(".bio").inner_text.presence

        Talk.create(:year => 2014, :title => title, :speaker => speaker, :abstract => abstract, :bio => bio)
      end
    end
    
    def create_railsconf_2013_talks
      talks_html = RestClient.get("http://railsconf.com/2013/talks.html")
      bios_html = RestClient.get("http://railsconf.com/2013/speakers.html")

      talks_doc = Nokogiri::HTML(talks_html)
      bios_doc = Nokogiri::HTML(bios_html)

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
      html = RestClient.get("http://lanyrd.com/2012/railsconf/")
      doc = Nokogiri::HTML(html)
      
      doc.css(".session-detail").each do |elm|
        title = elm.css("h3 a").inner_text
        speaker = elm.css("> p a").map(&:inner_text).join(", ").presence
        
        next if title.blank? || speaker.blank? || title.downcase.squish.starts_with?("keynote:")
        
        talk_url = "http://lanyrd.com#{elm.css("h3 a").first["href"]}"
        talk_html = RestClient.get(talk_url)
        talk_doc = Nokogiri::HTML(talk_html)
        
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
      sessions_html = RestClient.get("http://en.oreilly.com/rails#{year}/public/schedule/topic/General")
      sessions_doc = Nokogiri::HTML(sessions_html)
    
      sessions_doc.css(".en_session_title .url").each do |a|
        next if a.inner_text.to_s.downcase.squish == "lightning talks"
      
        html = RestClient.get("http://en.oreilly.com#{a["href"]}")
        doc = Nokogiri::HTML(html)
      
        title = doc.css("h1.summary").inner_text
        speaker = doc.css(".en_session_speakers a").map(&:inner_text).join(", ").presence
        abstract = doc.css(".en_session_description.description").inner_text
        bio = doc.css(".en_speaker_bio.note p").inner_text.presence
      
        Talk.create(:year => year, :title => title, :speaker => speaker, :abstract => abstract, :bio => bio)
      end
    end
    
    def create_railsconf_2007_talks
      sessions_html = RestClient.get("http://conferences.oreillynet.com/pub/w/51/sessions.html")
      sessions_doc = Nokogiri::HTML(sessions_html)
      
      sessions_doc.css(".s .summary a.url").each do |elm|
        link_text = elm.inner_text.to_s.downcase.squish
        next if link_text == "welcome" || link_text == "keynote"
        
        talk_url = "http://conferences.oreillynet.com#{elm["href"]}"
        talk_doc = Nokogiri::HTML(RestClient.get(talk_url))
        
        title = talk_doc.css("#session_view h2").inner_text
        speaker = talk_doc.css("#session_view > p > a").map(&:inner_text).join(", ").presence
        abstract = talk_doc.css("#session_desc").inner_text
        
        next if abstract.blank?
        
        bio = talk_doc.css("#session_view > p > a").map do |bio_link|
          bio_doc = Nokogiri::HTML(RestClient.get("http://conferences.oreillynet.com#{bio_link["href"]}"))
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
  
  def ngrams(n)
    words = abstract.squish.gsub(/[^[[:word:]]\s]/, '').to_s.downcase.split(" ")
    
    Array.wrap(n).each.with_object({}) do |this_n, hsh|
      hsh[this_n] = words.each_cons(this_n).to_a
    end
  end
  
  class << self
    def generate_all_ngram_data
      ALL_YEARS.each { |y| generate_ngram_data_by_year(y) }
    end
    
    def generate_ngram_data_by_year(year, opts = {})
      n = Array.wrap(opts[:n] || (1..MAX_NGRAM_SIZE).to_a)
      
      keys = n.map{ |num| sorted_set_key(year, num) }
      redis.del(*keys)
      keys.each{ |k| redis.zrem(TOTAL_KEY, k) }
      redis.zrem(ALL_YEARS_KEY, year)
      
      Talk.where(:year => year).find_each do |talk|
        talk.ngrams(n).each do |num, ngrams_ary|
          set_key = sorted_set_key(year, num)
          
          redis.zincrby(TOTAL_KEY, ngrams_ary.size, set_key)
          
          ngrams_ary.each do |val|
            redis.zincrby(set_key, 1, val.join(" "))
          end
        end
      end
      
      redis.zadd(ALL_YEARS_KEY, year, year)
    end
    handle_asynchronously :generate_ngram_data_by_year
  end
  
  # query ngrams code
  
  class << self
    def ngram_query(term)
      term.to_s.squish!.downcase!
      
      n = term.split(" ").size
      years = ALL_YEARS
      counts_hsh = {}
      
      redis.pipelined do
        years.each do |year|
          key = sorted_set_key(year, n)
          
          counts_hsh[year] = redis.zscore(key, term)
        end
      end
      
      counts_hsh.sort_by { |k,v| k }.map { |ary| ary[1].value.to_i }
    end
  end
end

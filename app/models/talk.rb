class Talk < ActiveRecord::Base
  validates_presence_of :year, :title, :abstract
  validates_uniqueness_of :title, :scope => :year
  
  # TO DO: 2006, 2007, 2012
  ALL_YEARS = [2008, 2009, 2010, 2011, 2013, 2014]
  
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
    
    ALL_YEARS.each do |year|
      handle_asynchronously :"create_railsconf_#{year}_talks"
    end
  end
end

module CheatSheetHelper
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

  def query(raw_term)
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
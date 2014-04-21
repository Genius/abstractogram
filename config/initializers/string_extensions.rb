class String
  def normalize_for_ngrams
    downcase.squish.remove_punctuation
  end
  
  def remove_punctuation
    gsub(/[^[[:word:]]\s]/, '')
  end
end
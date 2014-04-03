class String
  def fingerprint
    downcase.squish.remove_punctuation
  end
  
  def remove_punctuation
    gsub(/[^[[:word:]]\s]/, '')
  end
end
class TalksController < ApplicationController
  def query
    terms = get_terms_from_params
    render :json => {:title => terms.join(", "), :series => Talk.ngram_query(terms)}
  end
  
  private
  
  def get_terms_from_params
    params[:q].to_s.split(",").map{ |t| t.squish.gsub(Talk::WORDS_REGEX, '') }.select(&:present?).uniq
  end
end
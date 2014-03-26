class TalksController < ApplicationController
  def query
    render :json => Talk.ngram_query(get_terms_from_params)
  end
  
  private
  
  def get_terms_from_params
    params[:q].to_s.split(",").map{ |t| t.squish.gsub(Talk::WORDS_REGEX, '') }.select(&:present?)
  end
end
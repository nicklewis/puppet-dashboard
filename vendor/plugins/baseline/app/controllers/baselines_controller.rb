class BaselinesController < ApplicationController
  def make_baseline
    report = Report.find( params[:id] )
    report.baseline!
    redirect_to report
  end

  def index
    if request.format == :json
      limit = params[:limit].to_i
      search_term = params[:term].gsub(/([\\%_])/, "\\\\\\1")
      prefix_matches = Report.baselines.where(["host LIKE ?", "#{search_term}%"]).order("host ASC").limit(limit).map(&:host)
      substring_matches = Report.baselines.where(["host LIKE ?", "%#{search_term}%"]).order("host ASC").limit(limit).map(&:host)
      matches = (prefix_matches + substring_matches).uniq[0,limit]
      render :text => matches.to_json, :content_type => 'application/json'
    else
      render :status => 406
    end
  end
end

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
      matches = ["#{search_term}%", "%#{search_term}%"].map do |pattern|
        Baseline.all(:include => :node, :conditions => ["nodes.name LIKE ?", pattern], :order => "nodes.name ASC", :limit => limit).map(&:node).map(&:name)
      end.sum.uniq[0,limit]
      render :text => matches.to_json, :content_type => 'application/json'
    else
      render :status => 406
    end
  end
end

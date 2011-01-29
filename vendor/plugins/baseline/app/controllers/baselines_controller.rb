class BaselinesController < ApplicationController
  def make_baseline
    report = Report.find( params[:id] )
    report.baseline!
    redirect_to report
  end
end

class DiffsController < ApplicationController
  def diff
    @my_report = Report.find(params[:id])
    if params[:baseline_type] == "self"
      @baseline_report = @my_report.node.baseline_report
      raise ActiveRecord::RecordNotFound.new "Node #{@my_report.node.name} does not have a baseline report set" unless @baseline_report
    else
      @baseline_report = Report.baselines.find_by_host!(params[:baseline_host])
    end

    @diff = @baseline_report.diff(@my_report)
    @resource_statuses = Report.divide_diff_into_pass_and_fail(@diff)
  end
end

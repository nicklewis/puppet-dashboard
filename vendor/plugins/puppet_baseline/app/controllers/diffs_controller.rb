class DiffsController < ApplicationController
  def diff
    @my_report = Report.find(params[:id])
    if params[:baseline_type] == "self"
      baseline = Baseline.find_by_node(@my_report.node)
      raise ActiveRecord::RecordNotFound.new "Node #{@my_report.node.name} does not have a baseline report set" unless baseline
      @baseline_report = baseline.report
    else
      baseline = Baseline.find_by_node_name(params[:baseline_host])
      raise ActiveRecord::RecordNotFound.new("No baseline report for node #{params[:baseline_host]}") unless baseline
      @baseline_report = baseline.report
    end

    @diff = @baseline_report.diff(@my_report)
    @resource_statuses = Report.divide_diff_into_pass_and_fail(@diff)
  end

  def diff_group
    @node_group = NodeGroup.find(params[:id])
    unless params[:baseline_type] == "self"
      baseline = Baseline.find_by_node_name(params[:baseline_host])
      raise ActiveRecord::RecordNotFound.new("No baseline report for node #{params[:baseline_host]}") unless baseline
      @baseline = baseline.report
    end

    @nodes_without_latest_inspect_reports = []
    @nodes_without_baselines = []
    @nodes_without_differences = []
    @nodes_with_differences = []
    @node_group.all_nodes.sort_by(&:name).each do |node|
      baseline = @baseline
      if not baseline
        baseline_association = Baseline.find_by_node(node)
        baseline = baseline_association.report if baseline_association
      end
      @nodes_without_latest_inspect_reports << node and next unless node.last_inspect_report
      @nodes_without_baselines << node and next unless baseline

      report_diff = baseline.diff(node.last_inspect_report)
      resource_statuses = Report.divide_diff_into_pass_and_fail(report_diff)

      if resource_statuses[:failure].empty?
        @nodes_without_differences << node
      else
        @nodes_with_differences << {
          :baseline_report     => baseline,
          :last_inspect_report => node.last_inspect_report,
          :report_diff         => report_diff,
          :resource_statuses   => resource_statuses,
        }
      end
    end
  end
end

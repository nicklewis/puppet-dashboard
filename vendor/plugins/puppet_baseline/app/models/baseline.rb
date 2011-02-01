class Baseline < ActiveRecord::Base
  belongs_to :node
  belongs_to :report
  unloadable

  def self.report_is_baseline?(report)
    node_baseline = Baseline.find_by_node_id(report.node_id)
    !!(node_baseline && node_baseline.report_id == report.id)
  end

  def self.report_make_baseline!(report)
    raise IncorrectReportKind.new("expected 'inspect', got '#{report.kind}'") unless report.kind == "inspect"
    baseline = Baseline.find_or_initialize_by_node_id(report.node_id)
    baseline.report_id = report.id
    baseline.save!
  end

  def self.find_by_node(node)
    self.find_by_node_id(node.id)
  end

  def self.find_by_node_name(name)
    self.first(:joins => :node, :conditions => ["nodes.name = ?", name])
  end
end

Factory.define :baseline_inspect_report, :parent => :inspect_report do |report|
  report.after_create {|report| Baseline.report_make_baseline! report}
end

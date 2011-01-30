Registry.add_hook :core, :report_view_widgets, "500_baseline" do |view_renderer, report|
  if report.kind == "inspect"
    "<div class='section'>#{view_renderer.render 'diffs/baseline_selector', :diffee => report, :action => 'diff'}</div>"
  end
end
Registry.add_hook :core, :node_group_view_widgets, "500_baseline" do |view_renderer, node_group|
  view_renderer.render 'diffs/baseline_selector', :diffee => node_group, :action => 'diff_group'
end
Registry.add_hook :core, :node_view_widgets, "500_baseline" do |view_renderer, node|
  if node.baseline_report
    link = view_renderer.link_to node.baseline_report.time, node.baseline_report
    "<div class='section'><h3>Baseline: #{link}</div>"
  end
end
Registry.add_hook :report, :actions, "500_make_baseline" do |view_renderer, report|
  if report.kind == "inspect" and ! Baseline.report_is_baseline?(report)
    link = view_renderer.link_to "Make Baseline", {:id => report, :action => "make_baseline", :controller => "baselines"}, :method => :put, :confirm => 'Are you sure?', :class => "button"
    "<li>#{link}</li>"
  end
end
Registry.add_hook :report, :status_icon, "500_baseline" do |report|
  if Baseline.report_is_baseline?(report)
    :baseline
  end
end

Registry.add_hook :core, :report_view_widgets, "500_baseline", lambda { |view_renderer, report|
  if report.kind == "inspect" and Report.baselines.any?
    "<div class='section'>#{view_renderer.render 'diffs/baseline_selector', :diffee => report, :action => 'diff'}</div>"
  end
}
Registry.add_hook :core, :node_group_view_widgets, "500_baseline", lambda { |view_renderer, node_group|
  if Report.baselines.any?
    view_renderer.render 'diffs/baseline_selector', :diffee => node_group, :action => 'diff_group'
  end
}

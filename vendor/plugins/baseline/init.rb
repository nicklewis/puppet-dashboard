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
Registry.add_hook :core, :node_view_widgets, "500_baseline", lambda { |view_renderer, node|
  if node.baseline_report
    link = view_renderer.link_to node.baseline_report.time, node.baseline_report
    "<div class='section'><h3>Baseline: #{link}</div>"
  end
}
Registry.add_hook :report, :actions, "500_make_baseline", lambda { |view_renderer, report|
  if report.kind == "inspect" and ! report.baseline?
    link = view_renderer.link_to "Make Baseline", {:id => report, :action => "make_baseline"}, :method => :put, :confirm => 'Are you sure?', :class => "button"
    "<li>#{link}</li>"
  end
}

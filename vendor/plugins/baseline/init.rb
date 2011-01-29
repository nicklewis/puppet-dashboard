# Include hook code here
Registry.add_hook :core, :report_view_widgets, "500_baseline", lambda { |view_renderer, report|
  if report.kind == "inspect" and Report.baselines.any?
    "<div class='section'>#{view_renderer.render 'baseline_selector', :diffee => report, :action => 'diff'}</div>"
  end
}

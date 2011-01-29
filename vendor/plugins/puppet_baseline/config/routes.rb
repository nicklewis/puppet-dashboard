ActionController::Routing::Routes.draw do |map|
  map.diffs "reports/:id/diff", {:controller=>"diffs", :action=>"diff"}
  map.diff_group "node_groups/:id/diff", {:controller=>"diffs", :action=>"diff_group"}
  map.make_baseline "reports/:id/make_baseline", {:controller=>"baselines", :action=>"make_baseline"}
  map.baselines "reports/baselines", {:controller=>"baselines", :action=>"index"}
end


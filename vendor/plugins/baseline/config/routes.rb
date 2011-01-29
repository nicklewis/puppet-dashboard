ActionController::Routing::Routes.draw do |map|
  map.diffs "reports/:id/diff", {:controller=>"diffs", :action=>"diff"}
  map.diff_group "node_groups/:id/diff", {:controller=>"diffs", :action=>"diff_group"}
end


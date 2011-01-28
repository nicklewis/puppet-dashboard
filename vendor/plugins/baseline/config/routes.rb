ActionController::Routing::Routes.draw do |map|
  map.diffs "reports/:id/diff", {:controller=>"diffs", :action=>"diff"}
end


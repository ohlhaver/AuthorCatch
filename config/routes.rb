ActionController::Routing::Routes.draw do |map|
  
  map.about '/about', :controller => :about, :action => :about
  map.imprint '/imprint', :controller => :about, :action => :imprint
  map.feedback '/feedback', :controller => :about, :action => :feedback
  map.privacy '/privacy', :controller => :about, :action => :privacy
  map.help '/help', :controller => :about, :action => :help
  map.upgrade '/upgrade/:id', :controller => :about, :action => :power
  map.turn_off_wizard '/wizard/off/:id', :controller => :preferences, :action => 'turn_off_wizard'
  map.top_authors '/authors/top', :controller => 'authors', :action => 'top'
  map.my_authors '/authors/my', :controller => 'authors', :action => 'my'
  map.logout '/logout', :controller => 'application', :action => 'logout'
  map.home_rss '/home/:edition/:locale/:id.rss', :controller => 'home', :action => 'show', :format => 'rss'
  map.search_rss '/stories/:edition/:locale/:mode/:oq.rss', :controller => 'stories', :action => 'rss', :format => 'rss'
  map.section_rss '/sections/:locale/:oq.rss', :controller => 'sections', :action => 'rss', :format => 'rss'
  map.topic_rss '/topics/:locale/:oq.rss', :controller => 'topics', :action => 'rss', :format => 'rss'
  map.root :controller => 'home', :action => 'index'
  map.connect '/sections/create', :controller => 'sections', :action => :create
  map.resources :sections, :member => [ :up, :down, :hide ]
  map.resources :clusters
  map.resources :stories, :collection => [ :advanced, :search_results ]
  map.resources :topics, :member => [ :unhide, :hide, :up, :down ], :collection => [ :whats ]
  map.resources :authors, :member => [ :subscribe, :unsubscribe, :rate, :page ], :collection => [ :hide, :up, :down, :whats ]
  map.resources :sources, :member => [ :rate, :page ], :collection => [ :whats ]
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end

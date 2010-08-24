if defined?( Erubis )
Erubis::Helpers::RailsHelper.engine_class = Erubis::Eruby #Erubis::Eruby # or Erubis::FastEruby
#Erubis::Helpers::RailsHelper.init_properties = {}
Erubis::Helpers::RailsHelper.show_src = false
Erubis::Helpers::RailsHelper.preprocessing = true
end
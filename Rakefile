require './jarb4s.rb'

namespace :db do
  desc "Create our database"
  task :create_database do

    market = JARB4S::Base.new
    market.create_database

  end
end

namespace :jarb4s do
  desc "Get items"
  task :get_dota2_items do

    market = JARB4S::Dota2.new
    market.grab_all_them_items
    
  end
end
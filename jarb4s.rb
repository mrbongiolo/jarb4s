#J.A.R.B.4.S. - Just Another Ruthless Bot 4 Steam
module JARB4S
  
  STEAM_API_KEY = "D6025367E85E647787162E40CE8B1E58"

  class Base

    require 'rubygems'
    require 'bundler'

    Bundler.setup(:default)

    #require 'sqlite3'
    require 'active_record'
    require 'json'
    require 'money'
    require 'nokogiri'
    require 'open-uri'

    def initialize

      require './models/item.rb'

      ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
      #ActiveRecord::Base.establish_connection(
      #    adapter:  'sqlite3',
      #    database: 'db/development.sqlite3',
      #    pool: 5,
      #    timeout: 5000
      #)
    end

    def create_database
      begin
        ActiveRecord::Schema.define do
          create_table :items do |table|
            table.column  :title,                       :string,                  null: false
            table.column  :url,                         :text
            table.column  :image_url,                   :text
            table.column  :quantity,                    :integer
            table.column  :starting_price_cents,        :integer, :default => 0,  null: false
            table.column  :starting_price_currency,     :string,                  null: false
            #table.column  :highest_price_cents,        :integer, :default => 0,  null: false
            #table.column  :highest_price_currency,     :string,                  null: false
            #table.column  :average_price_cents,        :integer, :default => 0,  null: false
            #table.column  :average_price_currency,     :string,                  null: false
            #table.column  :latest_sold_price_cents,     :integer, :default => 0,  null: false
            #table.column  :latest_sold_price_currency,  :string,                  null: false
            table.column  :quality,                     :string
            table.column  :rarity,                      :string                                     #like: common, uncommon, rare, mythical
            table.column  :item_type,                   :string                                     #like: bow, claw, bracer, taunt
            table.column  :hero,                        :string
            table.column  :steam_class_id,              :string
            table.column  :steam_instance_id,           :string
            table.column  :steam_market_hash_name,      :string

            table.timestamps
          end
        end
      rescue
        puts '[error occured]'
      end
    end
  end

  class Dota2 < JARB4S::Base
    def get_json(url)
      JSON.parse( open(url).read )
    end

    def get_market_search_render(query = '', start = 0, count = 100)
      get_json("http://steamcommunity.com/market/search/render/?query=appid%3A570+#{URI.encode(query)}&start=#{start}&count=#{count}")
    end

    def get_market_listing_render(market_hash_name, count = 1)
      get_json("http://steamcommunity.com/market/listings/570/#{URI.encode(market_hash_name)}/render?count=#{count}")
    end

    def get_api_item_class_info(steam_class_id)
      get_json("http://api.steampowered.com/ISteamEconomy/GetAssetClassInfo/v0001?key=#{STEAM_API_KEY}&format=json&language=en&appid=570&class_count=1&classid0=#{steam_class_id}")
    end

    def grab_all_them_items(query = '')

      json = get_market_search_render(query) #initial query
      
      total_count = json['total_count'].to_i
      grabed =      0

      begin
        doc =  Nokogiri::HTML( json['results_html'] )

        doc.css('.market_listing_table_header').remove #remove the table header, we don't need it

        items = doc.css('a.market_listing_row_link')

        items.each do |item|

          title = item.at_css('span.market_listing_item_name').text

          puts "getting item #{title}"

          li = Item.find_by_title(title)
          
          if li
            li.quantity =       item.at_css('.market_listing_num_listings_qty').remove.text #we grab the quantity text and also remove it from the node so that it doesn't interfere in the price
            li.starting_price = item.at_css('.market_listing_right_cell.market_listing_num_listings > span').text.gsub(/\s+/,' ').gsub('Starting at:','')
            li.save
          else
            li = Item.new(title: title)

            li.url =            item.attr('href')
            li.image_url =      item.at_css('.market_listing_item_img').attr('src')
            li.quantity =       item.at_css('.market_listing_num_listings_qty').remove.text #we grab the quantity text and also remove it from the node so that it doesn't interfere in the price
            li.starting_price = item.at_css('.market_listing_right_cell.market_listing_num_listings > span').text.gsub(/\s+/,' ').gsub('Starting at:','')

            li.save

            temporary_market_hash_name = li.url.to_s.match(/http:\/\/steamcommunity.com\/market\/listings\/570\/([\w|\W]*)/)[1]
            puts "temporary market_hash_name: #{temporary_market_hash_name}"
            json_listing = get_market_listing_render(temporary_market_hash_name)

            li.steam_class_id =         json_listing['assets'].first[1].first[1].first[1]['classid']
            li.steam_instance_id =      json_listing['assets'].first[1].first[1].first[1]['instanceid']
            li.steam_market_hash_name = json_listing['assets'].first[1].first[1].first[1]['market_hash_name']

            li.save

            json_item_class_info = get_api_item_class_info(li.steam_class_id)

            tags = json_item_class_info['result'].first[1]['tags']

            tags.each do |tag|
              if tag[1]['category'] == 'Quality'
                li.quality = tag[1]['name']
              end
              if tag[1]['category'] == 'Rarity'
                li.rarity = tag[1]['name']
              end
              if tag[1]['category'] == 'Type'
                li.item_type = tag[1]['name']
              end
              if tag[1]['category'] == 'Hero'
                li.hero = tag[1]['name']
              end
            end

            li.save
          end

        end

        pagesize = json['pagesize'].to_i
        start =    json['start'].to_i

        grabed += pagesize
        start +=  pagesize

        json = get_market_search_render(query, start, pagesize)

      end while grabed < total_count
    end

    def show_items(limit = nil)
      Item.order('starting_price_cents ASC').limit(limit).each do |item|
        puts "##{item.id} - #{item.starting_price} - #{item.title}"
      end
    end

    #REGEX to find "tags" object from "http://steamcommunity.com/economy/itemclasshover/570/162265569/202272923" source
    #(?:"tags":\[)([\w*\W*]*)(?:\])

    #REGEX to find "market_has_name"
    #/"market_hash_name":"([\w|\s]*)"/


    #classid:231926809  #this recipe was already sold, I just wanna know if the classid is forever or not... it seems to be
    #http://api.steampowered.com/ISteamEconomy/GetAssetClassInfo/v0001?key=D6025367E85E647787162E40CE8B1E58&format=json&language=en&appid=570&class_count=1&classid0=231926809

    #this seems to return the price history of the item (only works when logged in)
    #http://steamcommunity.com/market/pricehistory/?appid=570&market_hash_name=Treasure%20of%20Incandescent%20Wax

    #get class_id
    # /"classid":"(\d+)"/

    #get items data via json
    #http://steamcommunity.com/market/listings/570/Jewel%20of%20the%20Forest%20Boots/render?count=1
  end
end

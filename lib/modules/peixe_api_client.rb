require 'rest_client'
require 'json'
require 'colorize'

module Modules
  class PeixeApiClient

    attr_accessor :products

    def initialize(process_all_regions=true)
      @regions_endpoint = 'https://api.peixeurbano.com.br/v3/pages'
      @deals_endpoint = 'http://api.peixeurbano.com.br/v3/deals/%{region}?offset=%{offset}&limit=100'
      @hypermindr_api = {
          development: {
            host: 'http://localhost:3000/v2',
            post_endpoint: '/product',
            delete_endpoint: '/delete_old_products',
            client_id: '5435a6106762722399000000',
            apikey: '43d70fd8165e0369132185ec0b75cad75f98adfeca9e1301f05f3e8872243414'
          },
          peixe: {
              host: 'http://localhost/v2',
              post_endpoint: '/product',
              delete_endpoint: '/delete_old_products',
              client_id: '53fe4d8b69702d78b7000000',
              apikey: 'f548ea2f5a17d3fd9a3c5be85513c0a0b07bb6791df1f3c10b9099714ccedc64'
          },
          test: {
              host: 'http://localhost:3000/v2',
              post_endpoint: '/product',
              delete_endpoint: '/delete_old_products',
              client_id: '53fe4d8b69702d78b7000000',
              apikey: 'f548ea2f5a17d3fd9a3c5be85513c0a0b07bb6791df1f3c10b9099714ccedc64'
          }
      }
      @process_regions = [{'page' => 'betatest'}] unless process_all_regions
      @products = {}
    end

    def get_regions
      return @process_regions if @process_regions.kind_of?(Array)
      url = @regions_endpoint
      begin
        result = RestClient::Request.execute(:method => :get, :url => url, :timeout => 2)
        parsed = JSON.parse(result)
        return parsed['response']
      rescue Exception => e
        puts "FAILED GET: #{url} => #{e.message}"
        # puts e.backtrace.inspect
        return []
      end
    end

    def get_deals(region)
      deals = []
      hasmore = true
      offset = 0
      while hasmore do
        begin
          url = @deals_endpoint % {region: region, offset: offset}
          result = RestClient::Request.execute(:method => :get, :url => url, :timeout => 60)
          parsed = JSON.parse(result)
          print('.')
        rescue Exception => e
          puts "FAILED GET: #{url} => #{e.message}"
          # puts e.backtrace.inspect
          parsed['response']['deals'] = []
          parsed['response']['hasMore'] = false
        end
        deals = deals + parsed['response']['deals']
        offset += parsed['response']['deals'].count
        hasmore = parsed['response']['hasMore']
      end
      deals
    end

    def get_deal(id)
      begin
        url = @deals_endpoint % {region: id, offset: 0}
        result = RestClient::Request.execute(:method => :get, :url => url, :timeout => 60)
        parsed = JSON.parse(result)
      rescue Exception => e
        puts "FAILED GET: #{url} => #{e.message}"
        # puts e.backtrace.inspect
        false
      end
      parsed['response']
    end

    def get_all_deals
      region_count=0
      total_deal_count=0
      get_regions.each do |region|
        region_count+=1
        puts '=========================='
        puts "#{region_count}. #{region['page']}"
        deals = get_deals region['page']
        if deals
          puts "#{deals.count} deals"
          total_deal_count += deals.count
          deals.each { |deal| add_to_products(deal, region)}
        else
          puts '0 or not found'
        end
        puts "#{@products.count} unique deals this far".light_black

      end
      puts '======================================================================='
      puts "#{region_count} regions found"
      puts "#{total_deal_count} total deals downloaded"
      puts "#{@products.count} unique deals"
      @products
    end

    def add_to_products(deal, region)
      unless @products.has_key?(deal['deal_id'])
        @products[deal['deal_id']] = deal
        @products[deal['deal_id']]['pages']=[]
      end
      @products[deal['deal_id']]['pages'] << region['page']
    end

    def post_product(product)
      api = @hypermindr_api[Rails.env.to_sym]
      payload = {
          client_id: api[:client_id],
          apikey: api[:apikey],
          resource: product.to_json,
          status: 'active',
          deleted_on: nil
      }
      url = "#{api[:host]}#{api[:post_endpoint]}/#{product['deal_id']}"
      begin
        result = RestClient::Request.execute(:method => :post, :url => url, :payload => payload, :timeout => 5)
        parsed = JSON.parse(result)
        puts result.red unless parsed['result']['success']
        parsed['result']['success']
      rescue Exception => e
        puts "FAILED POST: #{url} => #{e.message}"
        # puts e.backtrace.inspect
        false
      end
    end

    def seconds_to_time(seconds)
      [(seconds / 3600).round, (seconds / 60 % 60).round, (seconds % 60).round].map { |t| t.to_s.rjust(2,'0') }.join(':')
    end

    def delete_old_products(update_time)
      api = @hypermindr_api[Rails.env.to_sym]
      payload = {
          client_id: api[:client_id],
          apikey: api[:apikey],
          updated_before_date: update_time.to_i
      }
      url = "#{api[:host]}#{api[:delete_endpoint]}"
      begin
        result = RestClient::Request.execute(:method => :post, :url => url, :payload => payload, :timeout => 30)
        parsed = JSON.parse(result)
        puts result.red unless parsed['result']['success']
        parsed['result']['success']
      rescue Exception => e
        puts "FAILED POST: #{url} => #{e.message}"
        false
      end
    end

    def update_products
      start_time = Time.now
      download_start = Time.now
      get_all_deals
      puts "Time to download all deals: #{seconds_to_time(Time.now - download_start)}"

      puts "Posting products to hypermindR API"
      post_start = Time.now
      result = {success: 0, fail: 0}
      @products.each do |id, product|
        print('.')
        if post_product(product)
          result[:success]+=1
        else
          result[:fail]+=1
        end
      end
      print('\n')
      puts "#{result[:success]} succeeded".green if result[:success]>0
      puts "#{result[:fail]} failed".red if result[:fail]>0
      puts "Time to post all products: #{seconds_to_time(Time.now - post_start)}"
      delete_start = Time.now
      delete_old_products(post_start)
      puts "Time to delete products not on this update: #{seconds_to_time(Time.now - delete_start)}"
      puts "Total time elapsed: #{seconds_to_time(Time.now - start_time)}"
    end


  end


end
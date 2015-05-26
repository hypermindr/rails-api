module Modules
  class Mongo

    FILE_PATH = Rails.root.join 'lib/assets/mongo_indexes.json'

    INDEXES = {
        'admins' => [],
        'clients' => [{'key' => {'_slugs' => 1}, 'unique' => true }],
        'bla' => [],
        'activities' => [{'key' => {'_slugs' => 1}, 'unique' => true }],
        'users' => [],
        'products' => [],
        'stages' => [],
        'activity_by_date' => [],
        'chambs_items' => [],
        'articles_per_visit' => [],
        'df' => [],
        'recommendations' => [],
        'reporting' => [],
        'product_product_strengths' => [],
        'user_user_strengths' => [],
        'prod' => [],
        'reporting_ab' => [],
        'reporting_std' => [],
        'product_terms' => [],
        'product_models' => []
    }

    IGNORE_COLLECTIONS = %W{product_model user_model user_user_strengths user_user_strength_numerators user_user_strength_denominators product_product_strengths product_product_strength_numerators product_product_strength_denominators chambs_items}

    CHECK_OPTIONS = ['unique', 'dropDups']

    def initialize(dryrun: true, file_path: nil)
      @session = Mongoid.default_session
      @dryrun = dryrun
      @file_path = file_path || FILE_PATH
      # @indexes = INDEXES
      @ignore_collections = IGNORE_COLLECTIONS
      @maintain = []
    end

    def update_indexes
      return false unless read_input_file
      drop = get_deprecated_indexes
      create = get_missing_indexes

      puts 'DROP'.red
      puts '===='.red
      drop.each do |index|
        puts index.to_json.red
        drop_index index unless @dryrun
      end
      puts ''
      puts 'CREATE'.green
      puts '======'.green
      create.each do |index|
        puts index.to_json.green
        create_index index unless @dryrun
      end

      puts ''
      puts 'MAINTAIN'.yellow
      puts '========'.yellow
      @maintain.each do |index|
        puts index.to_json.yellow
      end

      true

    end

    def read_input_file()
      # puts "reading #{@file_path}"
      unless File.exists?(@file_path)
        puts "File not found: #{@file_path}"
        return false
      end
      json = File.open @file_path
      begin
        hash = JSON.parse(json.read)
        @indexes = hash['indexes']
        @ignore_collections = hash['ignore_collections']
      rescue
        puts 'Invalid json input file'
        return false
      end
      true
    end

    private
    def get_deprecated_indexes
      drop = []
      @session.collection_names.each do |collection|

        # ignore certain collections
        next if @ignore_collections.include? collection

        # loop through collections existing in the database
        @session[collection].indexes.each do |existing_index|
          # skip id index
          next if existing_index['key']=={'_id'=>1}
          index_ok=false
          @indexes[collection] ||= []
          @indexes[collection].each do |defined_index|

            if existing_index['key'].to_json==defined_index['key'].to_json
              index_ok = match_index defined_index, existing_index
              @maintain << {collection: collection, index: defined_index} if index_ok
              break
            end
          end
          drop << {collection: collection, index: existing_index} unless index_ok
        end
      end
      drop
    end

    def get_missing_indexes
      create = []
      @indexes.keys.each do |collection|
        @indexes[collection].each do |defined_index|
          index_ok=false
          @session[collection].indexes.each do |existing_index|
            if existing_index['key'].to_json==defined_index['key'].to_json
              index_ok = match_index defined_index, existing_index
              break
            end
          end
          create << {collection: collection, index: defined_index} unless index_ok
        end
      end
      create
    end

    def match_index(defined, existing)
      CHECK_OPTIONS.each do |option|
        return false if defined.has_key?(option) and !existing.has_key?(option)
        return false if existing.has_key?(option) and !defined.has_key?(option)
        if existing.has_key?(option) and defined.has_key?(option)
          return false unless existing[option] == defined[option]
        end
        return true
      end
    end

    def drop_index(index)
      @session[index[:collection]].indexes.drop(index[:index]['key'])
    end

    def create_index(index)
      options = {}
      CHECK_OPTIONS.each{|option| options[option] = index[:index][option] if index[:index].has_key?(option) }
      @session[index[:collection]].indexes.create(index[:index]['key'], options)
    end

  end
end
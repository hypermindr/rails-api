require 'zlib'

module Modules
  class Archiver

    def initialize(collection, date)
      @collection = collection
      @date = date
      @temp_path = '/tmp'
      @s3_bucket = 'hyperarchive'
      @records = 0
    end

    def archive
      start_time = Time.now
      log = Archive.create(table: @collection, filename: filename, start_time: start_time)
      generate
      upload_s3 @temp_path, filename if @records > 0
      File.delete("#{@temp_path}/#{filename}")
      puts "#{Time.now.to_s} - took #{(Time.now-start_time).round} secs"
      puts "=="
      log.update(finish_time: Time.now, records: @records)
    end

    def filename
      @filename ||= "#{@collection.to_s}.#{Rails.env}.#{@date.strftime('%Y%m%d')}.json.gz"
    end

    def generate
      puts "#{Time.now.to_s} - generating #{filename}"
      gz = Zlib::GzipWriter.open("#{@temp_path}/#{filename}")
      Mongoid.default_session[@collection].find(created_at: {'$gte' => Reporting.sod(@date), '$lt' => Reporting.eod(@date)}).each do |doc|
        gz.write("#{doc.to_json}\n")
        @records += 1
      end
      gz.close
      puts "#{Time.now.to_s} - finished generating #{filename} with #{@records} documents"
      true
    end

    def upload_s3(path, file)
      puts "#{Time.now.to_s} - Uploading #{file} to bucket #{@s3_bucket}... "

      # AWS SDK version 1
      bucket = s3.buckets[@s3_bucket]
      bucket.objects[file].write(:file => "#{path}/#{file}")

      # AWS SDK version 2
      # bucket = s3.bucket(@s3_bucket)
      # bucket.object(file).upload_file("#{path}/#{file}")
    end

    private

    def s3
      # AWS SDK version 1
      AWS::S3.new(access_key_id: Settings[:aws][:access_key_id], secret_access_key: Settings[:aws][:secret_access_key], region: Settings[:aws][:region])

      # AWS SDK version 2
      # Aws::S3::Resource.new(
      #     region: 'us-east-1',
      #     credentials: Aws::Credentials.new(@access_key_id, @secret_access_key)
      # )
    end

  end
end

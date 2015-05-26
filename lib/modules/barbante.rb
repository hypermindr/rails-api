require 'open-uri'

module Modules
	class Barbante
		@@target_version = '3.0.9'
		S3_Bucket = 'barbante'

		@@url = nil
		@@filename = nil
		@@filepath = nil
		@@installed_version = nil

		def self.define_url(host_config)
      settings = Settings[:barbante][host_config]
			host = settings[:host]
      port = settings[:port]
			protocol = settings[:protocol]
      if settings[:versioned_url]
        url = "#{protocol}://#{host}:#{port}/#{self.target_version}"
      else
        url = "#{protocol}://#{host}:#{port}"
      end
      @@url=url
		end

		def self.version(host_config: :default)
			result = self.get( action: 'version', args: [], timeout: 60, host_config: host_config)
			@@installed_version = result["version"]
			@@installed_version
		end

		def self.target_version
			file = Rails.root.join('.barbante-version')
			@@target_version ||= File.open(file, &:readline)
		end

		def self.is_target_version?
			puts "running version: #{self.version}"
			puts "target version: #{self.target_version}"
			@@installed_version == @@target_version
		end

		def self.process_product(product)
			logging_start
			product = product.attributes.except("_id").to_json
			result = self.post( action: "process_product", args: {env: Rails.env, product: product}, timeout: 300)
			logging_end
			result
		end

		def self.delete_product(external_product_id, deleted_on)
			logging_start
			result = self.post( action: "delete_product", args: {env: Rails.env, product_id: external_product_id, deleted_on: deleted_on}, timeout: 20)
			logging_end
			result
		end

		# def self.process_activity(external_user_id, external_product_id, activity, created_at, anonymous)
		# 	return {success: true, message: 'browse activities not processed'} if activity=='browse'
		# 	return {success: true, message: 'anonymous activities not processed'} if anonymous==1
		# 	logging_start
		# 	result = self.post( action: "process_activity", args: {env: Rails.env, external_user_id: external_user_id, external_product_id: external_product_id, activity_type: activity, activity_date: created_at}, timeout: 600)
		# 	logging_end
		# 	result
		# end

    def self.process_activity_fastlane(external_user_id, external_product_id, activity, created_at, anonymous)
      logging_start
      return {success: true, message: 'browse activities not processed'} if activity=='browse'

      result = self.post( action: "process_activity_fastlane", args: {env: Rails.env, external_user_id: external_user_id, external_product_id: external_product_id, activity_type: activity, activity_date: created_at}, timeout: 120)
      logging_end
      result
    end

    def self.process_activity_slowlane(external_user_id, external_product_id, activity, created_at, anonymous)
      logging_start
      return {success: true, message: 'browse activities not processed'} if activity=='browse'
      return {success: true, message: 'anonymous activities not processed'} if anonymous==1

      result = self.post( action: "process_activity_slowlane", args: {env: Rails.env, external_user_id: external_user_id, external_product_id: external_product_id, activity_type: activity, activity_date: created_at}, timeout: 1800)
      logging_end
      result
    end

		def self.process_impression(external_user_id, external_product_id, impression_date)
			self.post( action: "process_impression", args: {env: Rails.env, external_user_id: external_user_id, external_product_id: external_product_id, impression_date: impression_date}, timeout: 120)
		end

		def self.recommend(user_id, count, algorithm, filter=nil, timeout=5)
			logging_start
			begin
				filter_arg = filter ? {filter: filter} : nil # querystring parameter must be passed as hash
				result = self.get( action: "recommend", args: [Rails.env, user_id, count, algorithm], querystring: filter_arg, timeout: timeout, host_config: :cluster)
			rescue Exception => e
				puts e.message
				nil
			end
			logging_end
			result
		end

		def self.get_user_templates(user_id)
			logging_start
			result = self.get( action: "get_user_templates", args: [Rails.env, user_id], host_config: :cluster)
			logging_end
			result
		end

    def self.update_product_models
      system "python3.4 -m barbante.api.process_products_from_db #{Rails.env} --resume"
    end

		def self.update_templates(resource_type)
			# self.get "update_#{resource_type}_templates", [Rails.env], 3600
			# stdin, stdout, stderr = Open3.popen3("python3.4 -m barbante.api.update_#{resource_type}_templates #{Rails.env}")
			# response = stdout.gets
			# begin
			#   JSON::parse(response)
			# rescue
			#   nil
			# end
      # puts "update_#{resource_type}_templates"
			system "python3.4 -m barbante.api.generate_#{resource_type}_templates #{Rails.env}"
		end

		def self.consolidate_product_templates
			system "python3.4 -m barbante.api.consolidate_product_templates #{Rails.env} --all"
		end

		def self.download_installer
			AWS.config(access_key_id: Settings[:aws][:access_key_id], secret_access_key: Settings[:aws][:secret_access_key], region: Settings[:aws][:region])
			s3 = AWS::S3.new
			bucket = s3.buckets[S3_Bucket]
			@@filename = "barbante-#{self.target_version}.dev.tar.gz"
			@@filepath = "/tmp/#{@@filename}"

			raise 'Remote file does not exist' unless bucket.objects[@@filename].exists?

			File.open(@@filepath, 'wb') do |file|
			  bucket.objects[@@filename].read do |chunk|
			    file.write(chunk)
			  end
			end

			return @@filepath
		end

		def self.check_cluster_version(check_version=nil)
			check_version ||= target_version
			AWS.config(access_key_id: Settings[:aws][:access_key_id], secret_access_key: Settings[:aws][:secret_access_key], region: Settings[:aws][:region])
			Settings[:barbante].each do |label, settings|supra 20

				# only check if autoscaling group set
				next unless settings[:autoscaling_group]
				versioned = settings[:versioned_url]

				asg = AWS::AutoScaling::Group.new settings[:autoscaling_group]
				asg.ec2_instances.each do |instance|
					puts "#{instance.private_ip_address} - #{instance.status}"
					if versioned
						url = "#{settings[:protocol]}://#{instance.private_ip_address}:#{settings[:port]}/#{check_version}/version"
					else
						url = "#{settings[:protocol]}://#{instance.private_ip_address}:#{settings[:port]}/version"
					end
					begin
						response = RestClient::Request.execute(:method => :get, :url => url, :timeout => 5)
						puts response
						json_response = JSON::parse(response)
						raise 'invalid version' unless json_response['version']==check_version
					rescue Exception
						puts "Barbante version #{check_version} not available in instance #{instance.private_ip_address} (#{instance.id}).".red
						return false
					end
				end

				# now check if service responds accordingly
				unless version(host_config: :cluster)==check_version
					puts "Barbante version #{check_version} is correctly installed in all members of the cluster but configured host does not respond with correct version.".red
					return false
				end

			end

			return true
		end

		private

    def self.get(action: '', args: [], timeout: 5, querystring: nil, host_config: :default)
      self.request(action, args, 'get', timeout, querystring, host_config)
    end

    def self.post(action: '', args: {}, timeout: 5, querystring: nil, host_config: :default)
      self.request(action, args, 'post', timeout, querystring, host_config)
		end

    def self.request(action, args, method, timeout, querystring, host_config)

      self.define_url(host_config)

			begin
				if method=="get"
					url = "#{@@url}/#{action}/#{args.join("/")}"
					url = "#{url}?#{self.hash_to_querystring(querystring)}" if querystring
					# puts "get url => #{url}"
					response = RestClient::Request.execute(:method => :get, :url => url, :timeout => timeout, :open_timeout => timeout, :headers => {'tracerid' => Thread.current[:thread_uuid]})
				else
					url = "#{@@url}/#{action}"
          # puts "post url => #{url}"
					# puts "args => #{args}"
					headers = Thread.current[:thread_uuid].blank? ? {} : {'tracerid' => Thread.current[:thread_uuid]}
					response = RestClient::Request.execute(:method => :post, :url => url, :payload => args, :timeout => timeout, :open_timeout => timeout, :headers => headers)
				end
			rescue RestClient::Exception => e
				return {success: false, message: "#{e.response} #{e.message}"}
			rescue Exception => e
				return {success: false, message: e.message}
			end

      begin
        result = JSON::parse(response)
				result.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo} #return hash with keys converted to symbols
			rescue Exception
        {success: false, message: "invalid json returned: #{response}"}
			end

		end

		def self.hash_to_querystring(hash)
			return hash.map{|k,v| "#{k}=#{URI::encode(v)}"}.join("&") if hash.is_a?(Hash)
			nil
		end

		def self.logging_start
			Modules::LogTracer.start_trace name.to_s, caller[0][/`.*'/][1..-2]
		end

		def self.logging_end
			Modules::LogTracer.end_trace name.to_s, caller[0][/`.*'/][1..-2]
		end

	end
end

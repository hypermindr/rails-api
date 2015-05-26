require 'securerandom'
require 'rest_client'
require 'aws-sdk'
require 'json'
require 'socket'
require 'yaml'

module Modules

  class LogTracer
    #move configuration to yml
    @logger = Logger.new(STDOUT)

    # Creates a UUID from a random value.
    def self.createUUID()
      return SecureRandom.hex(16)
    end

    #build the message and start a thread to persist
    def self.writeLog(_request_id,_module,_class,_method,_stage,_msg)
      _timestamp = DateTime.now.strftime('%Q').to_f/10**3
      msg = {server: Socket.gethostname, tracerid: _request_id, endpoint: Thread.current[:endPointName], timestamp: _timestamp, module_name:_module, class_name:_class,method_name: _method, stage: _stage, message: _msg }

      flushLog(JSON.generate(msg))
    end

    def self.flushLog(_message)
      Rails.logger.info(_message)
    end

    def self.get_thread_uuid
      Thread.current[:thread_uuid] ||= createUUID
    end

    def self.get_thread_endpoint(endpoint)
      Thread.current[:endPointName] ||= endpoint
    end

    def self.clean_up
      Thread.current[:thread_uuid]=nil
      Thread.current[:endPointName]=nil
    end

    def self.start_trace(class_name, method_name, msg='START')
      get_thread_endpoint(method_name)
      writeLog get_thread_uuid, class_name.split('::').first, class_name, method_name, 'B', msg
    end

    def self.end_trace(class_name, method_name, msg='END')
      writeLog get_thread_uuid, class_name.split('::').first, class_name, method_name, 'E', msg
    end

  end
end
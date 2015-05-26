
module Modules
  class QueueMeter

    RATE_SLEEP_TIME = 20
    @queue_increase_rate=0
    @queue_process_rate=0

    def self.measure
      adjust_slowlane_limit
      get_queue_rate
      metric_data = [
          { :metric_name => 'queue_size', :value => get_global_queue_size },
          { :metric_name => 'workers', :value => get_workers_size },
          { :metric_name => 'queue_increase_rate', :value => @queue_increase_rate },
          { :metric_name => 'queue_process_rate', :value => @queue_process_rate },
          { :metric_name => 'instances', :value => get_processes_size },
          { :metric_name => 'slowlane_limit', :value => adjust_slowlane_limit },
          { :metric_name => 'impression_queue', :value => get_queue_size('impression') },
          { :metric_name => 'fastlane_queue', :value => get_queue_size('barbante_activity_fastlane') },
          { :metric_name => 'slowlane_queue', :value => get_queue_size('barbante_activity_slowlane') },
          { :metric_name => 'product_queue', :value => get_queue_size('product') },
          { :metric_name => 'user_activity_queue', :value => get_queue_size('user_activity') }
      ]
      publish_metric(metric_data)
    end

    def self.get_global_queue_size
      stats = Sidekiq::Stats.new
      stats.enqueued
    end

    def self.get_processed_size
      stats = Sidekiq::Stats.new
      stats.processed
    end

    def self.get_queue_rate
      queue = get_global_queue_size
      processed = get_processed_size
      sleep(RATE_SLEEP_TIME.seconds)
      @queue_increase_rate = (get_global_queue_size - queue)/RATE_SLEEP_TIME
      @queue_process_rate = (get_processed_size - processed)/RATE_SLEEP_TIME
    end

    def self.get_workers_size
      workers = Sidekiq::Workers.new
      workers.size
    end

    def self.get_processes_size
      ps = Sidekiq::ProcessSet.new
      ps.size
    end

    def self.get_queue_size(queue_name)
      Sidekiq::Queue[queue_name].size
    end

    def self.publish_metric(metric_data)
      cw = AWS::CloudWatch.new(
          :access_key_id => Settings[:aws][:access_key_id],
          :secret_access_key => Settings[:aws][:secret_access_key])

      cw.put_metric_data(
          :namespace => "#{Rails.application.class.parent_name}:#{Rails.env}",
          :metric_data => metric_data
      )
    end

    def self.adjust_slowlane_limit
      processes = get_processes_size
      impression_waiting = get_queue_size('impression')

      min_impression_workers = processes<=20 ? 4 : 8

      Sidekiq::Queue['barbante_activity_slowlane'].limit=processes-min_impression_workers if impression_waiting<100 and processes > min_impression_workers
      Sidekiq::Queue['barbante_activity_slowlane'].limit=0 if impression_waiting>50000
      Sidekiq::Queue['barbante_activity_slowlane'].limit
    end

  end
end

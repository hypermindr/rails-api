#Author: ricardo
#Implementation of a customer logger to override Rails default logger. The main goal is intercept thread_uuid for debugging purposes.

class ActiveSupport::BufferedLogger
  def formatter=(formatter)
    @log.formatter = formatter
  end
end

class Formatter
  SEVERITY_TO_TAG_MAP     = {'DEBUG'=>'DEBUG', 'INFO'=>'INFO', 'WARN'=>'WARNING', 'ERROR'=>'ERROR', 'FATAL'=>'CRITICAL', 'UNKNOWN'=>'FROM MARS'}
  SEVERITY_TO_COLOR_MAP   = {'DEBUG'=>'0;37', 'INFO'=>'32', 'WARN'=>'33', 'ERROR'=>'31', 'FATAL'=>'31', 'UNKNOWN'=>'37'}
  USE_SEVERITIES = true

  def call(severity, time, progname, msg)
    if msg.nil? || msg.empty?
      return
    end
    if USE_SEVERITIES
      formatted_severity = sprintf("%-3s","#{SEVERITY_TO_TAG_MAP[severity]}")
    else
      formatted_severity = sprintf("%-5s","#{severity}")
    end

    formatted_time = time.strftime("%Y-%m-%d %H:%M:%S.") << time.usec.to_s[0..2].rjust(3)
    color = SEVERITY_TO_COLOR_MAP[severity]

   if Thread.current[:thread_uuid].blank?
      "\033[0;37m#{formatted_time}\033[0m [\033[#{color}m#{formatted_severity}\033[0m] #{msg.strip}, pid: #{$$} \n"
   else
      "\033[0;37m#{formatted_time}\033[0m [\033[#{color}m#{formatted_severity}\033[0m] #{msg.strip}, pid: #{$$}, tracerid: #{Thread.current[:thread_uuid]}\n"
   end
  end

end

Rails.logger.formatter = Formatter.new
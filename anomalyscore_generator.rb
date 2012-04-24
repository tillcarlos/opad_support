#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'bundler'
Bundler.require(:default)


module CommandLineFlags extend OptiFlagSet
  # (port: 55672) # http://localhost:55672/#/
  optional_flag "amqphost"
  optional_flag "exchange"
  optional_flag "keys"
  optional_flag "period"

  and_process!
end 

### INITIALIZE GLOBAL OPAD DEPLOYMENT SETTINGS ###
puts "Starting alerting_queue_reader with $opad_home=#{($opad_home ||= ENV['OPAD_HOME'])}"
begin puts "Please set $OPAD_HOME env var!" 
      exit end if $opad_home.nil?
require File.join($opad_home, 'common', 'read_config')


host = ARGV.flags.amqphost || $config[:support]['alerting_queue']['host']
exchange_name = ARGV.flags.exchange || $config[:support]['alerting_queue']['exchange']
period = ARGV.flags.period || $config[:support]['generator']['period']
keys = ARGV.flags.keys.split(',') if ARGV.flags.keys
keys ||= [$config[:opad]['aspect_id']]


puts "ANOMALY SCORE GENERATOR"
puts "======================="
puts "Server: #{host}"
puts "Exchange: #{exchange_name}"
puts "Keys: #{keys.join(',')}"
puts "Random Anomaly Score every: #{period} seconds"
puts "======================="


  
EM.run do
  connection = AMQP.connect(:host => host, :logging => true)
  channel = AMQP::Channel.new(connection)
  exchange = AMQP::Exchange.new(channel, :topic, exchange_name)
  puts "Connecting to AMQP on host #{host}. Running #{AMQP::VERSION} version of the gem. Accessing exchange #{exchange_name}"


  trap("INT"){ EM.next_tick { connection.close { EM.stop_event_loop} } }

  EM.add_periodic_timer(period) do
    keys.each do |key|
      anomaly_data = {"time" => Time.now, "aspect" => key, 
        "measure" => 50+450*rand(), "anomaly" => rand().to_s[0..3], 
        "forecast" => 50+450*rand()}
      
      logjam_data = {
          "total_time" => 4450+450*rand()}
      encoded_data = logjam_data.to_json

      begin
        exchange.publish(encoded_data, :routing_key => key)  
        puts "published #{encoded_data} to exchange: '#{exchange_name}' with routing_key: '#{key}'"
      rescue => e
        puts "Error publishing to queue #{e}"        
      end

    end
  end


end

#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'bundler'
Bundler.require(:default)



module CommandLineFlags extend OptiFlagSet
  optional_flag "amqphost"
  optional_flag "exchange"
  optional_flag "keys"
  optional_flag "delay"
  optional_flag "filename"

  and_process!
end 

### INITIALIZE GLOBAL OPAD DEPLOYMENT SETTINGS ###
puts "Starting alerting_queue_reader with $opad_home=#{($opad_home ||= ENV['OPAD_HOME'])}"
begin puts "Please set $OPAD_HOME env var!" 
      exit end if $opad_home.nil?
require File.join($opad_home, 'common', 'read_config')


host = ARGV.flags.amqphost || $config[:support]['replayer']['host']
exchange_name = ARGV.flags.exchange || $config[:support]['replayer']['exchange']
delay = ARGV.flags.delay || $config[:support]['replayer']['delay']
filename = ARGV.flags.filename || $config[:support]['replayer']['filename']

keys = ARGV.flags.keys.split(',') if ARGV.flags.keys
keys ||= $config[:support]['replayer']['keys'].split(',')


puts "PERFORMANCE REPLAYER"
puts "======================="
puts "Server: #{host}"
puts "Exchange: #{exchange_name}"
puts "Keys: #{keys.join(',')}"
puts "Delay: #{delay}"
puts "From file #{filename}"
puts "======================="


  
EM.run do
  connection = AMQP.connect(:host => host, :logging => true)
  channel = AMQP::Channel.new(connection)
  exchange = AMQP::Exchange.new(channel, :topic, exchange_name)
  puts "Connecting to AMQP on host #{host}. Running #{AMQP::VERSION} version of the gem. Accessing exchange #{exchange_name}"


  trap("INT"){ EM.next_tick { connection.close { EM.stop_event_loop} } }

  file = File.open(filename, 'r')
  lines = 0
  
  EM.add_periodic_timer(delay) do
    if (line = file.gets)
      lines = lines + 1
      
      data = JSON.parse(line)
      unixMillis = DateTime.parse(data['time']).to_time.to_i * 1000
        
      data['time_millis'] = unixMillis
      encoded_data = data.to_json
      
      keys.each do |key|
        exchange.publish encoded_data, :key => key
        puts "published #{encoded_data} on amqp on host #{host} to exchange #{exchange_name} for routing key: #{key}"
      end
    else
      puts "Read #{lines} lines."
      EM.stop_event_loop
    end
  end







end

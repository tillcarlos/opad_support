#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'bundler'
Bundler.require(:default)



module CommandLineFlags extend OptiFlagSet
  optional_flag "amqphost"
  optional_flag "exchange"
  optional_flag "keys"
  optional_flag "fields"
  optional_flag "period"

  and_process!
end 

### INITIALIZE GLOBAL OPAD DEPLOYMENT SETTINGS ###
puts "Starting alerting_queue_reader with $opad_home=#{($opad_home ||= ENV['OPAD_HOME'])}"
begin puts "Please set $OPAD_HOME env var!" 
      exit end if $opad_home.nil?
require File.join($opad_home, 'common', 'read_config')


host = ARGV.flags.amqphost || $config[:support]['generator']['host']
exchange_name = ARGV.flags.exchange || $config[:support]['generator']['exchange']
period = ARGV.flags.period || $config[:support]['generator']['period']
keys = ARGV.flags.keys.split(',') if ARGV.flags.keys
keys ||= $config[:support]['generator']['keys'].split(',')
fields = ARGV.flags.keys.split(',') if ARGV.flags.fields
fields ||= $config[:support]['generator']['fields'].split(',')



puts "LOGJAM STREAM GENERATOR"
puts "======================="
puts "Server: #{host}"
puts "Exchange: #{exchange_name}"
puts "Keys: #{keys.join(',')}"
puts "Fields: #{fields.join(',')}"
puts "Period: #{period}"
puts "======================="


  
  
EM.run do
  connection = AMQP.connect(:host => host)
  channel = AMQP::Channel.new(connection)
  exchange = channel.topic(exchange_name)
  ap "AMQP host=#{host} exchange=#{exchange_name} key=#{keys}."

  trap("INT"){ EM.next_tick { connection.close { EM.stop_event_loop} } }

  EM.add_periodic_timer(period) do
    keys.each do |key|
      count = 50+450*rand()
      data = fields.inject({"count" => count}){|h,k| h[k] = 100*rand*count; h}
      encoded_data = data.to_json
      puts "#{encoded_data} to queue=#{exchange_name}, routing_key => #{key}"
      # publish performance data
      exchange.publish(encoded_data, :key => key)  
    end
  end
end

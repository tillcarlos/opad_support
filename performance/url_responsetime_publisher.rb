#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'bundler'
Bundler.require(:default)
require 'net/https'

# simple example: https://gist.github.com/723279
# handling multiple sockets: http://jxs.me/2010/09/07/github-live-via-eventmachine-websockets/
# http://rubyamqp.info/articles/working_with_exchanges/


module CommandLineFlags extend OptiFlagSet
  # (port: 55672) # http://localhost:55672/#/
  optional_flag "amqphost"
  optional_flag "exchange"
  optional_flag "key"
  optional_flag "idents"
  optional_flag "urls"
  optional_flag "period"

  and_process!
end 

### INITIALIZE GLOBAL OPAD DEPLOYMENT SETTINGS ###
puts "Starting alerting_queue_reader with $opad_home=#{($opad_home ||= ENV['OPAD_HOME'])}"
begin puts "Please set $OPAD_HOME env var!" 
      exit end if $opad_home.nil?
require File.join($opad_home, 'common', 'read_config')


host = ARGV.flags.amqphost || $config[:support]['perfclient']['host']
exchange_name = ARGV.flags.exchange || $config[:support]['perfclient']['exchange']
key = ARGV.flags.key || $config[:support]['perfclient']['key']
period = ARGV.flags.period || $config[:support]['perfclient']['period']

#idents = ARGV.flags.idents.split(',') if ARGV.flags.idents
#idents ||= $config[:support]['perfclient']['idents'].split(',')

if ARGV.flags.urls
  urls = {}
  ARGV.flags.urls.split('§').each{ |u| urls[u] = u }
end

urls ||= $config[:support]['perfclient']['urls']


puts "PERFORMANCE CLIENT PUBLISHER"
puts "============================"
puts "Server: #{host}"
puts "Exchange: #{exchange_name}"
puts "URLs: #{urls.keys.join(',')} (separate via § on command line)"
puts "Period: #{period}"
puts "============================"


EM.run do
  connection = AMQP.connect(:host => host)
  channel = AMQP::Channel.new(connection)
  exchange = channel.topic(exchange_name)
  ap "rabbit host=#{host} exchange=#{exchange_name} key=#{key}."

  trap("INT"){ EM.next_tick { connection.close { EM.stop_event_loop} } }

  EM.add_periodic_timer(period) do
    data = {}
    
    urls.each do |ident, url|
      start_m = Time.new

      html = Net::HTTP.get(URI.parse(url))

      stop_m = Time.new
      diff = stop_m - start_m

      data[ident] = diff
      
      puts "#{data[ident]} was the response time of url #{url}, publishing it to json identifier: #{ident}"
    end
    
    data[:time] = Time.now
    exchange.publish(data.to_json, :key => key)
  end
end











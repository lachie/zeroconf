#!/usr/bin/env ruby
$:.unshift '../../lib'
$:.unshift '../../ext'

require 'optparse'
require 'dnssd'

Thread.abort_on_exception = true

options = {}

ARGV.options do |opts|
  opts.on('-nnumber_of_services', '--number=number_of_services',
					'Number of services to register') { |options[:number]| }
  opts.on('-ttype', '--type=servicetype',
					'Type of service (e.g. _http._tcp)') { |options[:type]| }
  opts.on('-pport','--port=port',
					'Base port on which to advertise (will increase by 1 for every advertisement)') { |options[:port]| }
  opts.parse!
end


def register_stress(number, type)
  registrars = []
  1.upto(number) do |num|
		text_record = DNSSD::TextRecord.new("1st"=>"First#{num}", "last"=>"Last#{num}")
    registrars << DNSSD.register( "ruby stress #{num}",
																	type, "local",
																	8080 + num, text_record) do |service, register|
      puts register.inspect
    end
  end
  registrars
end

if __FILE__ == $0 then
  number = options[:number] || 300
  number = number.to_i
  type = options[:type] || "_http._tcp"
  port = options[:port] || 8080
  registrars = register_stress(number, type)
  puts "#{number} services registered...press enter to terminate"
  gets
  registrars.each do |reg|
    reg.stop
  end
end


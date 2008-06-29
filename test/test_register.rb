begin
  require 'dnssd'
rescue LoadError => error
  #This is just in case you did not install, but want to test
  $:.unshift '../lib'
  $:.unshift '../ext'
  require 'dnssd'
end

Thread.abort_on_exception = true

require 'dnssd'

print "Press <return> to start (and <return to end): "
$stdin.gets

#registrar_no_block = DNSSD.register("hey ruby", "_http._tcp", nil, 8081)
#registrar_no_block.stop

registrar = DNSSD.register("chad ruby", "_http._tcp", nil, 8080) do |register_reply|
  puts "Registration: #{register_reply.inspect}"
end
sleep 4
browse_service = DNSSD.browse('_http._tcp') do |browse_reply|
  puts "Browse: #{browse_reply.inspect}"
end

$stdin.gets

registrar.stop
browse_service.stop


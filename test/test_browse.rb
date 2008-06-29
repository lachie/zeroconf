begin
  require 'dnssd'
rescue LoadError => error
  #This is just in case you did not install, but want to test
  $:.unshift '../lib'
  $:.unshift '../ext'
  require 'dnssd'
end

Thread.abort_on_exception = true

print "Press <return> to start (and <return to end): "
$stdin.gets


browse_service = DNSSD.browse('_presence._tcp') do |browse_reply|
  puts browse_reply.inspect
end


$stdin.gets

browse_service.stop


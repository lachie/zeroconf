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

rservice = DNSSD.resolve("foo bar", "_http._tcp", "local") do |resolve_reply|
	puts resolve_reply.inspect
end

rservice.stop

$stdin.gets

begin
  require 'dnssd'
rescue LoadError => error
  #This is just in case you did not install, but want to test
  $:.unshift '../lib'
  $:.unshift '../ext'
  require 'dnssd'
end

require 'pp'

Thread.abort_on_exception = true

class ChatNameResolver
  def self.resolve_add(browse_reply)
    Thread.new(browse_reply) do |browse_reply|
      DNSSD.resolve(browse_reply.name, browse_reply.type, browse_reply.domain) do |resolve_reply|
        puts "Adding: #{resolve_reply.inspect}"
				#pp resolve_reply.text_record
        resolve_reply.service.stop
      end
    end
  end
  def self.resolve_remove(browse_reply)
    Thread.new(browse_reply) do |browse_reply|
      DNSSD.resolve(browse_reply.name, browse_reply.type, browse_reply.domain) do |resolve_reply|
        puts "Removing: #{resolve_reply.inspect}"
        resolve_reply.service.stop
      end
    end
  end
end

print "Press <return> to start (and <return to end): "
$stdin.gets

browse_service = nil

Thread.new {
  browse_service = DNSSD.browse('_presence._tcp') do |browse_reply|
		puts "Browsing: #{browse_reply.inspect}"
    if (browse_reply.flags.add?)
      ChatNameResolver.resolve_add(browse_reply)
    else
      ChatNameResolver.resolve_remove(browse_reply)
    end
  end
  sleep 10
}

$stdin.gets

browse_service.stop

puts browse_service.inspect


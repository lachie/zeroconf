=begin
  Copyright (C) 2005 Sam Roberts

  This library is free software; you can redistribute it and/or modify it
  under the same terms as the ruby language itself, see the file COPYING for
  details.
=end

require 'ipaddr'
require 'logger'
require 'singleton'

require 'net/dns'
require 'net/dns/resolvx'

BasicSocket.do_not_reverse_lookup = true

module Net
  module DNS

    #:main:Net::DNS::MDNS
    #:title:net-mdns - multicast DNS and DNS service discovery
    #
    # Author::     Sam Roberts <sroberts@uniserve.com>
    # Copyright::  Copyright (C) 2005 Sam Roberts
    # License::    May be distributed under the same terms as Ruby
    # Version::    0.4
    # Homepage::   http://dnssd.rubyforge.org/net-mdns
    # Download::   http://rubyforge.org/frs/?group_id=316
    #
    # == Summary
    #
    # An implementation of a multicast DNS (mDNS) responder.  mDNS is an
    # extension of hierarchical, unicast DNS to link-local multicast, used to
    # do service discovery and address lookups over local networks. It is
    # most widely known because it is part of Apple's OS X.
    #
    # net-mdns consists of:
    # - Net::DNS::MDNSSD: a high-level API for browsing, resolving, and advertising
    #   services using DNS-SD over mDNS that aims to be compatible with DNSSD, see
    #   below for more information.
    # - Resolv::MDNS: an extension to the 'resolv' resolver library that adds
    #   support for multicast DNS.
    # - Net::DNS::MDNS: the low-level APIs and mDNS responder at the core of
    #   Resolv::MDNS and Net::DNS::MDNSSD.
    #
    # net-mdns can be used for:
    # - name to address lookups on local networks
    # - address to name lookups on local networks
    # - discovery of services on local networks
    # - advertisement of services on local networks
    #
    # == Client Example
    #
    # This is an example of finding all _http._tcp services, connecting to
    # them, and printing the 'Server' field of the HTTP headers using Net::HTTP
    # (from link:exhttp.txt):
    #
    #   require 'net/http'
    #   require 'thread'
    #   require 'pp'
    #   
    #   # For MDNSSD
    #   require 'net/dns/mdns-sd'
    #   
    #   # To make Resolv aware of mDNS
    #   require 'net/dns/resolv-mdns'
    #   
    #   # To make TCPSocket use Resolv, not the C library resolver.
    #   require 'net/dns/resolv-replace'
    #   
    #   # Use a short name.
    #   DNSSD = Net::DNS::MDNSSD
    #   
    #   # Sync stdout, and don't write to console from multiple threads.
    #   $stdout.sync
    #   $lock = Mutex.new
    #   
    #   # Be quiet.
    #   debug = false
    #   
    #   DNSSD.browse('_http._tcp') do |b|
    #     $lock.synchronize { pp b } if debug
    #     DNSSD.resolve(b.name, b.type) do |r|
    #       $lock.synchronize { pp r } if debug
    #       begin
    #         http = Net::HTTP.new(r.target, r.port)
    #   
    #         path = r.text_record['path'] || '/'
    #   
    #         headers = http.head(path)
    #   
    #         $lock.synchronize do
    #           puts "#{r.name.inspect} on #{r.target}:#{r.port}#{path} was last-modified #{headers['server']}"
    #         end
    #       rescue
    #         $lock.synchronize { puts $!; puts $!.backtrace }
    #       end
    #     end
    #   end
    #   
    #   # Hit enter when you think that's all.
    #   STDIN.gets
    #
    # == Server Example
    #
    # This is an example of advertising a webrick server using DNS-SD (from
    # link:exwebrick.txt).
    #
    #   require 'webrick'
    #   require 'net/dns/mdns-sd'
    #   
    #   DNSSD = Net::DNS::MDNSSD
    #   
    #   class HelloServlet < WEBrick::HTTPServlet::AbstractServlet
    #     def do_GET(req, resp)   
    #       resp.body = "hello, world\n"
    #       resp['content-type'] = 'text/plain'
    #       raise WEBrick::HTTPStatus::OK
    #     end
    #   end
    #   
    #   server = WEBrick::HTTPServer.new( :Port => 8080 )
    #   
    #   server.mount( '/hello/', HelloServlet )
    #   
    #   handle = DNSSD.register("hello", '_http._tcp', 'local', 8080, 'path' => '/hello/')
    #   
    #   ['INT', 'TERM'].each { |signal| 
    #     trap(signal) { server.shutdown; handle.stop; }
    #   }
    #   
    #   server.start
    # 
    # == Samples
    #
    # There are a few command line utilities in the samples/ directory:
    # - link:mdns.txt, mdns.rb is a command line interface for to Net::DNS::MDNSSD (or to DNSSD)
    # - link:v1demo.txt, v1demo.rb is a sample provided by Ben Giddings showing
    #   the call sequences to use with Resolv::MDNS for service resolution. This
    #   predates Net::DNS::MDNSSD, so while its a great sample, you might want
    #   to look at mdns.rb instead.
    # - link:v1mdns.txt, v1mdns.rb is a low-level utility for exercising Resolv::MDNS.
    # - link:mdns-watch.txt, mdns-watch.rb is a utility that dumps all mDNS traffic, useful
    #   for debugging.
    # 
    # == Comparison to the DNS-SD Extension
    #
    # The DNS-SD project at http://dnssd.rubyforge.org is another
    # approach to mDNS and service discovery.
    #
    # DNS-SD is a compiled ruby extension implemented on top of the dns_sd.h APIs
    # published by Apple. These APIs work by contacting a local mDNS daemon
    # (through unix domain sockets) and should be more efficient since they
    # use a daemon written in C by a dedicated team at Apple.
    #
    # Currently, the only thing I'm aware of net-mdns doing that DNS-SD
    # doesn't is integrate into the standard library so that link-local domain
    # names can be used throughout the standard networking classes, and allow
    # querying of arbitrary DNS record types. There is no reason DNS-SD can't
    # do this, it just needs to wrap DNSServiceQueryRecord() and expose it, and
    # that will happen sometime soon.
    #
    # Since net-mdns doesn't do significantly more than DNSSD, why would you be
    # interested in it?
    #
    # The DNS-SD extension requires the dns_sd.h C language APIs for the Apple
    # mDNS daemon. Installing the Apple responder can be quite difficult, and
    # requires a running daemon.  It also requires compiling the extension. If
    # you need a pure ruby implementation, or if building DNS-SD turns out to be
    # difficult for you, net-mdns may be useful to you.
    #
    # == For More Information
    #
    # See the following:
    # - draft-cheshire-dnsext-multicastdns-04.txt for a description of mDNS
    # - RFC 2782 for a description of DNS SRV records
    # - draft-cheshire-dnsext-dns-sd-02.txt for a description of how to
    #   use SRV, PTR, and TXT records for service discovery
    # - http://www.dns-sd.org (a list of services is at http://www.dns-sd.org/ServiceTypes.html).
    # - http://dnssd.rubyforge.org - for DNSSD, a C extension for communicating
    #   with Apple's mDNSResponder daemon.
    #
    # == TODO
    #
    # See link:TODO.
    #
    # == Thanks
    #
    # - to Tanaka Akira for resolv.rb, I learned a lot about meta-programming
    #   and ruby idioms from it, as well as getting an almost-complete
    #   implementation of the DNS message format and a resolver framework I
    #   could plug mDNS support into.
    #
    # - to Charles Mills for letting me add net-mdns to DNS-SD's Rubyforge
    #   project when he hardly knew me, and hadn't even seen any code yet.
    #
    # - to Ben Giddings for promising to use this if I wrote it, which was
    #   the catalyst for resuming a year-old prototype.
    #
    # == Author
    # 
    # Any feedback, questions, problems, etc., please contact me, Sam Roberts,
    # via dnssd-developers@rubyforge.org, or directly.
    module MDNS
      class Answer
        attr_reader :name, :ttl, :data, :cacheflush
        # TOA - time of arrival (of an answer)
        attr_reader :toa
        attr_accessor :retries

        def initialize(name, ttl, data, cacheflush)
          @name = name
          @ttl = ttl
          @data = data
          @cacheflush = cacheflush
          @toa = Time.now.to_i
          @retries = 0
        end

        def type
          data.class
        end

        def refresh
          # Percentage points are from mDNS
          percent = [80,85,90,95][retries]

          # TODO - add a 2% of TTL jitter
          toa + ttl * percent / 100 if percent
        end

        def expiry
          toa + (ttl == 0 ? 1 : ttl)
        end

        def expired?
          true if Time.now.to_i > expiry
        end

        def absolute?
          @cacheflush
        end

        def to_s
          s = "#{name.to_s} (#{ttl}) "
          s << '!' if absolute?
          s << '-' if ttl == 0
          s << " #{DNS.rrname(data)}"

          case data
          when IN::A
            s << " #{data.address.to_s}"
          when IN::PTR
            s << " #{data.name}"
          when IN::SRV
            s << " #{data.target}:#{data.port}"
          when IN::TXT
            s << " #{data.strings.first.inspect}#{data.strings.length > 1 ? ', ...' : ''}"
          when IN::HINFO
            s << " os=#{data.os}, cpu=#{data.cpu}"
          else
            s << data.inspect
          end
          s
        end
      end

      class Question
        attr_reader :name, :type, :retries
        attr_writer :retries

        # Normally we see our own question, so an update will occur right away,
        # causing retries to be set to 1. If we don't see our own question, for
        # some reason, we'll ask again a second later.
        RETRIES = [1, 1, 2, 4]

        def initialize(name, type)
          @name = name
          @type = type

          @lastq = Time.now.to_i

          @retries = 0
        end

        # Update the number of times the question has been asked based on having
        # seen the question, so that the question is considered asked whether
        # we asked it, or another machine/process asked.
        def update
          @retries += 1
          @lastq = Time.now.to_i
        end

        # Questions are asked 4 times, repeating at increasing intervals of 1,
        # 2, and 4 seconds.
        def refresh
          r = RETRIES[retries]
          @lastq + r if r
        end

        def to_s
          "#{@name.to_s}/#{DNS.rrname @type} (#{@retries})"
        end
      end

      class Cache # :nodoc:
        # asked: Hash[Name] -> Hash[Resource] -> Question
        attr_reader :asked

        # cached: Hash[Name] -> Hash[Resource] -> Array -> Answer
        attr_reader :cached

        def initialize
          @asked = Hash.new { |h,k| h[k] = Hash.new }

          @cached = Hash.new { |h,k| h[k] = (Hash.new { |a,b| a[b] = Array.new }) }
        end

        # Return the question if we added it, or nil if question is already being asked.
        def add_question(qu)
          if qu && !@asked[qu.name][qu.type]
            @asked[qu.name][qu.type] = qu
          end
        end

        # Cache question. Increase the number of times we've seen it.
        def cache_question(name, type)
          if qu = @asked[name][type]
            qu.update
          end
          qu
        end

        # Return cached answer, or nil if answer wasn't cached.
        def cache_answer(an)
          answers = @cached[an.name][an.type]

          if( an.absolute? )
            # Replace all answers older than a ~1 sec [mDNS].
            # If the data is the same, don't delete it, we don't want it to look new.
            now_m1 = Time.now.to_i - 1
            answers.delete_if { |a| a.toa < now_m1 && a.data != an.data }
          end

          old_an = answers.detect { |a| a.name == an.name && a.data == an.data }

          if( !old_an )
            # new answer, cache it
            answers << an
          elsif( an.ttl == 0 )
            # it's a "remove" notice, replace old_an
            answers.delete( old_an )
            answers << an
          elsif( an.expiry > old_an.expiry)
            # it's a fresher record than we have, cache it but the data is the
            # same so don't report it as cached
            answers.delete( old_an )
            answers << an
            an = nil
          else
            # don't cache it
            an = nil
          end

          an
        end

        def answers_for(name, type)
          answers = []
          if( name.to_s == '*' )
            @cached.keys.each { |n| answers += answers_for(n, type) }
          elsif( type == IN::ANY )
            @cached[name].each { |rtype,rdata| answers += rdata }
          else
            answers += @cached[name][type]
          end
          answers
        end

        def asked?(name, type)
          return true if name.to_s == '*'

          t = @asked[name][type] || @asked[name][IN::ANY]

          # TODO - true if (Time.now - t) < some threshold...

          t
        end

      end

      class Responder # :nodoc:
        include Singleton

        # mDNS link-local multicast address
        Addr = "224.0.0.251"
        Port = 5353
        UDPSize = 9000

        attr_reader :cache
        attr_reader :log
        attr_reader :hostname
        attr_reader :hostaddr
        attr_reader :hostrr

        # Log messages to +log+. +log+ must be +nil+ (no logging) or an object
        # that responds to debug(), warn(), and error(). Default is a Logger to
        # STDERR that logs only ERROR messages.
        def log=(log)
          unless !log || (log.respond_to?(:debug) && log.respond_to?(:warn) && log.respond_to?(:error))
            raise ArgumentError, "log doesn't appear to be a kind of logger"
          end
          @log = log
        end

        def debug(*args)
          @log.debug( *args ) if @log
        end
        def warn(*args)
          @log.warn( *args ) if @log
        end
        def error(*args)
          @log.error( *args ) if @log
        end

        def initialize
          @log = Logger.new(STDERR)

          @log.level = Logger::ERROR

          @mutex = Mutex.new

          @cache = Cache.new

          @queries = []

          @services = []

          @hostname = Name.create(Socket.gethostname)
          @hostname.absolute = true
          @hostaddr = Socket.getaddrinfo(@hostname.to_s, 0, Socket::AF_INET, Socket::SOCK_STREAM)[0][3]
          @hostrr   = [ @hostname, 240, IN::A.new(@hostaddr) ]
          @hostaddr = IPAddr.new(@hostaddr).hton

          debug( "start" )

          # TODO - I'm not sure about how robust this is. A better way to find the default
          # ifx would be to do:
          #   s = UDPSocket.new
          #   s.connect(any addr, any port)
          #   s.getsockname => struct sockaddr_in => ip_addr
          # But parsing a struct sockaddr_in is a PITA in ruby.

          @sock = UDPSocket.new

          # Set the close-on-exec flag, if supported.
          if Fcntl.constants.include? 'F_SETFD'
            @sock.fcntl(Fcntl::F_SETFD, 1)
          end

          # Allow 5353 to be shared.
          so_reuseport = 0x0200
          # The definition on OS X, where it is required, and where the shipped
          # ruby version (1.6) does not have Socket::SO_REUSEPORT. The definition
          # seems to be shared by at least some other BSD-derived stacks.
          if Socket.constants.include? 'SO_REUSEPORT'
            so_reuseport = Socket::SO_REUSEPORT
          end
          begin
            @sock.setsockopt(Socket::SOL_SOCKET, so_reuseport, 1)
          rescue
            warn( "set SO_REUSEPORT raised #{$!}, try SO_REUSEADDR" )
            so_reuseport = Socket::SO_REUSEADDR
            @sock.setsockopt(Socket::SOL_SOCKET, so_reuseport, 1)
          end

          # Request dest addr and ifx ids... no.

          # Bind to our port.
          @sock.bind(Socket::INADDR_ANY, Port)

          # Join the multicast group.
          #  option is a struct ip_mreq { struct in_addr, struct in_addr }
          ip_mreq =  IPAddr.new(Addr).hton + @hostaddr
          @sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, ip_mreq)
          @sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF, @hostaddr)

          # Set IP TTL for outgoing packets.
          @sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_TTL, 255)
          @sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, 255)

          # Apple source makes it appear that optval may need to be a "char" on
          # some systems:
          #  @sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, 255 as int)
          #     - or -
          #  @sock.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, 255 as byte)

          # Start responder and cacher threads.

          @waketime = nil

          @cacher_thrd = Thread.new do
            begin
              cacher_loop
            rescue
              error( "cacher_loop exited with #{$!}" )
              $!.backtrace.each do |e| error(e) end
            end
          end

          @responder_thrd = Thread.new do
            begin
              responder_loop
            rescue
              error( "responder_loop exited with #{$!}" )
              $!.backtrace.each do |e| error(e) end
            end
          end
        end

        def responder_loop
          loop do
            # from is [ AF_INET, port, name, addr ]
            reply, from = @sock.recvfrom(UDPSize)
            qaddr = from[3]
            qport = from[1]

            @mutex.synchronize do

              begin
                msg =  Message.decode(reply)

                qid  = msg.id
                qr   = msg.qr == 0 ? 'Q' : 'R'
                qcnt = msg.question.size
                acnt = msg.answer.size

                debug( "from #{qaddr}:#{qport} -> id #{qid} qr=#{qr} qcnt=#{qcnt} acnt=#{acnt}" )

                if( msg.query? )
                  # Cache questions:
                  # - ignore unicast queries
                  # - record the question as asked
                  # - TODO flush any answers we have over 1 sec old (otherwise if a machine goes down, its
                  #    answers stay until there ttl, which can be very long!)
                  msg.each_question do |name, type, unicast|
                    next if unicast

                    debug( "++ q #{name.to_s}/#{DNS.rrname(type)}" )

                    @cache.cache_question(name, type)
                  end

                  # Answer questions for registered services:
                  # - don't multicast answers to unicast questions
                  # - let each service add any records that answer the question
                  # - delete duplicate answers
                  # - delete known answers (see MDNS:7.1)
                  # - send an answer if there are any answers
                  amsg = Message.new(0)
                  amsg.rd = 0
                  amsg.qr = 1
                  amsg.aa = 1
                  msg.each_question do |name, type, unicast|
                    next if unicast

                    debug( "ask? #{name}/#{DNS.rrname(type)}" )
                    @services.each do |svc|
                      svc.answer_question(name, type, amsg)
                    end
                  end

                  amsg.question.uniq!
                  amsg.answer.uniq!
                  amsg.additional.uniq!

                  amsg.answer.delete_if do |an|
                    msg.answer.detect do |known|
                      # Recall: an = [ name, ttl, data, cacheflush ]
                      if(an[0] == known[0] && an[2] == known[2] && (an[1]/2) < known[1])
                        true # an is a duplicate, and known is not about to expire
                      else
                        false
                      end
                    end
                  end

                  send(amsg, qid, qaddr, qport) if amsg.answer.first

                else
                  # Cache answers:
                  cached = []
                  msg.each_answer do |n, ttl, data, cacheflush|

                    a = Answer.new(n, ttl, data, cacheflush)
                    debug( "++ a #{ a }" )
                    a = @cache.cache_answer(a)
                    debug( " cached" ) if a

                    # If a wasn't cached, then its an answer we already have, don't push it.
                    cached << a if a

                    wake_cacher_for(a)
                  end

                  # Push answers to Queries:
                  # TODO - push all answers, let the Query do what it wants with them.
                  @queries.each do |q|
                    answers = cached.select { |an| q.subscribes_to? an }

                    debug( "push #{answers.length} to #{q}" )

                    q.push( answers )
                  end

                end

              rescue DecodeError
                warn( "decode error: #{reply.inspect}" )
              end

            end # end sync
          end # end loop
        end

        # wake sweeper if cache item needs refreshing before current waketime
        def wake_cacher_for(item)
          return unless item

          if !@waketime || @waketime == 0 || item.refresh < @waketime
            @cacher_thrd.wakeup
          end
        end

        def cacher_loop
          delay = 0

          loop do

            if delay > 0
              sleep(delay)
            else
              sleep
            end

            @mutex.synchronize do
              debug( "sweep begin" )

              @waketime = nil

              msg = Message.new(0)
              msg.rd = 0
              msg.qr = 0
              msg.aa = 0

              now = Time.now.to_i

              # the earliest question or answer we need to wake for
              wakefor = nil

              # TODO - A delete expired, that yields every answer before
              # deleting it (so I can log it).
              # TODO - A #each_answer?
              @cache.cached.each do |name,rtypes|
                rtypes.each do |rtype, answers|
                  # Delete expired answers.
                  answers.delete_if do |an|
                    if an.expired?
                      debug( "-- a #{an}" )
                      true
                    end
                  end
                  # Requery answers that need refreshing, if there is a query that wants it.
                  # Remember the earliest one we need to wake for.
                  answers.each do |an|
                    if an.refresh
                      unless @queries.detect { |q| q.subscribes_to? an }
                        debug( "no refresh of: a #{an}" )
                        next
                      end
                      if now >= an.refresh
                        an.retries += 1
                        msg.add_question(name, an.data.class)
                      end
                      # TODO: cacher_loop exited with comparison of Bignum with nil failed, v2mdns.rb:478:in `<'
                      begin
                      if !wakefor || an.refresh < wakefor.refresh
                        wakefor = an
                      end
                      rescue
                        error( "an #{an.inspect}" )
                        error( "wakefor #{wakefor.inspect}" )
                        raise
                      end
                    end
                  end
                end
              end

              @cache.asked.each do |name,rtypes|
                # Delete questions no query subscribes to, and that don't need refreshing.
                rtypes.delete_if do |rtype, qu|
                  if !qu.refresh || !@queries.detect { |q| q.subscribes_to? qu }
                    debug( "no refresh of: q #{qu}" )
                    true
                  end
                end
                # Requery questions that need refreshing.
                # Remember the earliest one we need to wake for.
                rtypes.each do |rtype, qu|
                  if now >= qu.refresh
                    msg.add_question(name, rtype)
                  end
                  if !wakefor || qu.refresh < wakefor.refresh
                    wakefor = qu
                  end
                end
              end

              msg.question.uniq!

              msg.each_question { |n,r| debug( "-> q #{n} #{DNS.rrname(r)}" ) }

              send(msg) if msg.question.first

              @waketime = wakefor.refresh if wakefor

              if @waketime
                delay = @waketime - Time.now.to_i
                delay = 1 if delay < 1

                debug( "refresh in #{delay} sec for #{wakefor}" )
              else
                delay = 0
              end

              debug( "sweep end" )
            end
          end # end loop
        end

        def send(msg, qid = nil, qaddr = nil, qport = nil)
          begin
            msg.answer.each do |an|
              debug( "-> an #{an[0]} (#{an[1]}) #{an[2].to_s} #{an[3].inspect}" )
            end
            msg.additional.each do |an|
              debug( "-> ad #{an[0]} (#{an[1]}) #{an[2].to_s} #{an[3].inspect}" )
            end
            # Unicast response directly to questioner if source port is not 5353.
            if qport && qport != Port
              debug( "unicast for qid #{qid} to #{qaddr}:#{qport}" )
              msg.id = qid
              @sock.send(msg.encode, 0, qaddr, qport)
            end
            # ID is always zero for mcast, don't repeat questions for mcast
            msg.id = 0
            msg.question.clear unless msg.query?
            @sock.send(msg.encode, 0, Addr, Port)
          rescue
            error( "send msg failed: #{$!}" )
            raise
          end
        end

        def query_start(query, qu)
          @mutex.synchronize do
            begin
              debug( "start query #{query} with qu #{qu.inspect}" )

              @queries << query

              qu = @cache.add_question(qu)

              wake_cacher_for(qu)

              answers = @cache.answers_for(query.name, query.type)

              query.push( answers )
             
              # If it wasn't added, then we already are asking the question,
              # don't ask it again.
              if qu
                qmsg = Message.new(0)
                qmsg.rd = 0
                qmsg.qr = 0
                qmsg.aa = 0
                qmsg.add_question(qu.name, qu.type)
                
                send(qmsg)
              end
            rescue
              warn( "fail query #{query} - #{$!}" )
              @queries.delete(query)
              raise
            end
          end
        end

        def query_stop(query)
          @mutex.synchronize do
            debug( "query #{query} - stop" )
            @queries.delete(query)
          end
        end

        def service_start(service, announce_answers = [])
          @mutex.synchronize do
            begin
              @services << service

              debug( "start service #{service.to_s}" )

              if announce_answers.first
                smsg = Message.new(0)
                smsg.rd = 0
                smsg.qr = 1
                smsg.aa = 1
                announce_answers.each do |a|
                  smsg.add_answer(*a)
                end
                send(smsg)
              end

            rescue
              warn( "fail service #{service} - #{$!}" )
              @queries.delete(service)
              raise
            end
          end
        end

        def service_stop(service)
          @mutex.synchronize do
            debug( "service #{service} - stop" )
            @services.delete(service)
          end
        end

      end # Responder

      # An mDNS query implementation.
      module QueryImp
      # This exists because I can't inherit Query to implement BackgroundQuery, I need
      # to do something different with the block (yield it in a thread), and there doesn't seem to be
      # a way to strip a block when calling super.
        include Net::DNS

        def subscribes_to?(an) # :nodoc:
          if( name.to_s == '*' || name == an.name )
            if( type == IN::ANY || type == an.type )
              return true
            end
          end
          false
        end

        def push(answers) # :nodoc:
          @queue.push(answers) if answers.first
          self
        end

        # The query +name+ from Query.new.
        attr_reader :name
        # The query +type+ from Query.new.
        attr_reader :type

        # Block, returning answers when available.
        def pop
          @queue.pop
        end

        # Loop forever, yielding answers as available.
        def each # :yield: answers
          loop do
            yield pop
          end
        end

        # Number of waiting answers.
        def length
          @queue.length
        end

        # A string describing this query.
        def to_s
          "q?#{name}/#{DNS.rrname(type)}"
        end

        def initialize_(name, type = IN::ANY)
          @name = Name.create(name)
          @type = type
          @queue = Queue.new

          qu = @name != "*" ? Question.new(@name, @type) : nil

          Responder.instance.query_start(self, qu)
        end

        def stop
          Responder.instance.query_stop(self)
          self
        end
      end # Query

      # An mDNS query.
      class Query
        include QueryImp

        # Query for resource records of +type+ for the +name+. +type+ is one of
        # the constants in Net::DNS::IN, such as A or ANY. +name+ is a DNS
        # Name or String, see Name.create. 
        #
        # +name+ can also be the wildcard "*". This will cause no queries to
        # be multicast, but will return every answer seen by the responder.
        #
        # If the optional block is provided, self and any answers are yielded
        # until an explicit break, return, or #stop is done.
        def initialize(name, type = IN::ANY) # :yield: self, answers
          initialize_(name, type)

          if block_given?
            self.each do |*args|
              yield self, args
            end
          end
        end

      end # Query

      # An mDNS query.
      class BackgroundQuery
        include QueryImp

        # This is like Query.new, except the block is yielded in a background
        # thread, and is not optional.
        #
        # In the thread, self and any answers are yielded until an explicit
        # break, return, or #stop is done.
        def initialize(name, type = IN::ANY, &proc) #:yield: self, answers
          unless proc
            raise ArgumentError, "require a proc to yield in background!"
          end

          initialize_(name, type)

          @thread = Thread.new do
            begin
              loop do
                answers = self.pop

                proc.call(self, answers)
              end
            rescue
              # This is noisy, but better than silent failure. If you don't want
              # me to print your exceptions, make sure they don't get out of your
              # block!
              $stderr.puts "query #{self} yield raised #{$!}"
              $!.backtrace.each do |e| $stderr.puts(e) end
            ensure
              Responder.instance.query_stop(self)
            end
          end
        end

        def stop
          @thread.kill
          self
        end
      end # BackgroundQuery

      class Service
        include Net::DNS

        # Questions we can answer:
        # @instance:
        #   name.type.domain -> SRV, TXT
        # @type:
        #   type.domain -> PTR:name.type.domain
        # @enum:
        #   _services._dns-sd._udp.<domain> -> PTR:type.domain
        def answer_question(name, rtype, amsg)
          case name
          when @instance
            # See [DNSSD:14.2]
            case rtype.object_id
            when IN::ANY.object_id
              amsg.add_question(name, rtype)
              amsg.add_answer(@instance, @srvttl, @rrsrv)
              amsg.add_answer(@instance, @srvttl, @rrtxt)
              amsg.add_additional(*@hostrr) if @hostrr
 
            when IN::SRV.object_id
              amsg.add_question(name, rtype)
              amsg.add_answer(@instance, @srvttl, @rrsrv)
              amsg.add_additional(*@hostrr) if @hostrr
 
            when IN::TXT.object_id
              amsg.add_question(name, rtype)
              amsg.add_answer(@instance, @srvttl, @rrtxt)
            end

          when @type
            # See [DNSSD:14.1]
            case rtype.object_id
            when IN::ANY.object_id, IN::PTR.object_id
              amsg.add_question(name, rtype)
              amsg.add_answer(@type,     @ptrttl, @rrptr)
              amsg.add_additional(@instance, @srvttl, @rrsrv)
              amsg.add_additional(@instance, @srvttl, @rrtxt)
              amsg.add_additional(*@hostrr) if @hostrr
            end

          when @enum
            case rtype.object_id
            when IN::ANY.object_id, IN::PTR.object_id
              amsg.add_question(name, rtype)
              amsg.add_answer(@type, @ptrttl, @rrenum)
            end

          end
        end

        # Default - 7 days
        def ttl=(secs)
          @ttl = secs.to_int
        end
        # Default - 0
        def priority=(secs)
          @priority = secs.to_int
        end
        # Default - 0
        def weight=(secs)
          @weight = secs.to_int
        end
        # Default - .local
        def domain=(domain)
          @domain = DNS::Name.create(domain.to_str)
        end
        # Set key/value pairs in a TXT record associated with SRV.
        def []=(key, value)
          @txt[key.to_str] = value.to_str
        end

        def to_s
          "MDNS::Service: #{@instance} is #{@target}:#{@port}>"
        end

        def inspect
          "#<#{self.class}: #{@instance} is #{@target}:#{@port}>"
        end

        def initialize(name, type, port, txt = {}, target = nil, &proc)
          # TODO - escape special characters
          @name = DNS::Name.create(name.to_str)
          @type = DNS::Name.create(type.to_str)
          @domain = DNS::Name.create('local')
          @port = port.to_int
          if target
            @target = DNS::Name.create(target)
            @hostrr = nil
          else
            @target = Responder.instance.hostname
            @hostrr = Responder.instance.hostrr
          end

          @txt = txt || {}
          @ttl = nil
          @priority = 0
          @weight = 0

          proc.call(self) if proc

          @srvttl = @ttl ||  240
          @ptrttl = @ttl || 7200

          @domain = Name.new(@domain.to_a, true)
          @type = @type + @domain
          @instance = @name + @type
          @enum = Name.create('_services._dns-sd._udp.') + @domain

          # build the RRs

          @rrenum = IN::PTR.new(@type)

          @rrptr = IN::PTR.new(@instance)

          @rrsrv = IN::SRV.new(@priority, @weight, @port, @target)

          strings = @txt.map { |k,v| k + '=' + v }

          @rrtxt = IN::TXT.new(*strings)

          # class << self
          #   undef_method 'ttl='
          # end
          #  -or-
          # undef :ttl=
          #
          # TODO - all the others

          start
        end

        def start
          Responder.instance.service_start(self, [
               [@type, @ptrttl, @rrptr],
               [@instance, @srvttl, @rrsrv],
               [@instance, @srvttl, @rrtxt],
               @hostrr
            ].compact)
          self
        end

        def stop
          Responder.instance.service_stop(self)
          self
        end

      end
    end

  end
end

if $0 == __FILE__

include Net::DNS

$stdout.sync = true
$stderr.sync = true

log = Logger.new(STDERR)
log.level = Logger::DEBUG

MDNS::Responder.instance.log = log

require 'pp'

# I don't want lines of this report intertwingled.
$print_mutex = Mutex.new

def print_answers(q,answers)
  $print_mutex.synchronize do
    puts "#{q} ->"
    answers.each do |an| puts "  #{an}" end
  end
end

questions = [
  [ IN::ANY, '*'],
# [ IN::PTR, '_http._tcp.local.' ],
# [ IN::SRV, 'Sam Roberts._http._tcp.local.' ],
# [ IN::ANY, '_ftp._tcp.local.' ],
# [ IN::ANY, '_daap._tcp.local.' ],
# [ IN::A,   'ensemble.local.' ],
# [ IN::ANY, 'ensemble.local.' ],
# [ IN::PTR, '_services._dns-sd.udp.local.' ],
  nil
]

questions.each do |question|
  next unless question

  type, name = question
  MDNS::BackgroundQuery.new(name, type) do |q, answers|
    print_answers(q, answers)
  end
end

=begin
q = MDNS::Query.new('ensemble.local.', IN::ANY)
print_answers( q, q.pop )
q.stop

svc = MDNS::Service.new('julie', '_example._tcp', 0xdead) do |s|
  s.ttl = 10
end
=end

Signal.trap('USR1') do
  PP.pp( MDNS::Responder.instance.cache, $stderr )
end

sleep

end


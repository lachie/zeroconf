if __FILE__ == $0
  Thread.abort_on_exception = true
## Our sample code
  service = DNSSD::Service.advertise_http("Chad's server", 8808) do |service|
    puts service.inspect
    #service.name_changed? {|name| my_widget.update(name) }
  end
  sleep 4
  service.stop

  #browser = DNSSD::Browser.for_http do |service|
    #host, port = service.resolve #optionally returns [host, port, iface]
  #end
  #sleep 4
  #browser.stop
  #if(browser.more_coming?)
    #puts "blah"
  #end
  #browser.service_discovered? {|service|}
  #browser.service_lost? {|service|}
  #browser.on_changed  { 
  # get current values for UI update
  #}
  #browser.all_current #=> [service1, service2]
  #browser.changed? 
end

=begin

collects the resolve results and trys each one (overlap)...when one succeeds, it cancels
the other checks and returns.

=end



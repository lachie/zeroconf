=begin
  Copyright (C) 2005 Sam Roberts

  This library is free software; you can redistribute it and/or modify it
  under the same terms as the ruby language itself, see the file COPYING for
  details.
=end

require 'net/dns/resolv'

class Resolv
  class DNS

    class Message
      # Returns true if message is a query.
      def query?
        qr == 0
      end

      # Returns true if message is a response.
      def response?
        !query?
      end
    end

  end
end

class Resolv

  # The default resolvers.
  def self.default_resolvers
    DefaultResolver.resolvers
  end

  # The resolvers configured.
  attr_reader :resolvers

end

class Resolv
  class DNS

    class Config
      # A name that has a number of labels greater than than +ndots+ will be looked
      # up directly. The default value of +ndots+ is 1, so "example" would not be
      # looked up directly, but "example.com" would be (it has 1 dot). Names ending in a dot, like
      # "org.", will always be looked up directly, regardless of the setting of ndots.
      attr_reader :ndots
      # A series of search suffixes to use if the name being looked up does not end
      # in a dot.
      attr_reader :search
      # The list of nameservers to query, should be dotted IP addresses, not
      # domain names.
      attr_reader :nameservers
    end

  end
end

class Resolv
  class DNS
    module Label

      class Str
        # Str is-a String, allow it to be compared to one.
        def to_str
          return @string
        end
        # Case-insensitive comparison.
        def <=>(s)
          @downcase <=> s.downcase
        end
      end

    end
  end
end


class Resolv
  class DNS

    class Name
      # Append +arg+ to this Name. +arg+ can be a String or a Name.
      #
      # Returns +self+.
      def <<(arg)
        arg = Name.create(arg)
        @labels.concat(arg.to_a)
        @absolute = arg.absolute?
        self
      end

      # Returns a new Name formed by concatenating +self+ with +arg+. +arg+ can
      # be a String or a Name.
      def +(arg)
        arg = Name.create(arg)
        Name.new(@labels + arg.to_a, arg.absolute?)
      end

      # Set whether +self+ is absolute or not. This is particularly useful when
      # creating a Name from a String, since the trailing "." is rarely used in
      # string representations of domain names, even when the domain name is
      # fully qualified. This makes them very difficult to compare to a Name
      # returned from the DNS record decoders, because DNS names are always
      # absolute.
      def absolute=(abs)
        @absolute = abs ? true : false
      end

      # Returns whether two names are equal, disregarding the absolute? property
      # of the names.
      #
      # Note that this differs from #==, which does not consider two names
      # equal if they differ in absoluteness.
      def equal?(name)
        n = Name.create(name)

        @labels == n.to_a
      end
    end

  end
end


class Resolv
  class DNS

    # DNS names are hierarchical in a similar sense to ruby classes/modules,
    # and the comparison operators are defined similarly to those of Module. A
    # name is +<+ another if it is a subdomain of it.
    #   www.example.com < example.com # -> true
    #   example.com < example.com # -> false
    #   example.com <= example.com # -> true
    #   com < example.com # -> false
    #   bar.com < example.com # -> nil
    class Name
      def related?(name)
        n = Name.create(name)

        l = length < n.length ? length : n.length

        @labels[-l, l] == n.to_a[-l, l]
      end

      def lt?(name)
        n = Name.create(name)
        length > n.length && to_a[-n.length, n.length] == n.to_a
      end


      # Summary:
      #   name < other   =>  true, false, or nil
      # 
      # Returns true if +name+ is a subdomain of +other+. Returns 
      # <code>nil</code> if there's no relationship between the two. 
      def <(name)
        n = Name.create(name)

        return nil unless self.related?(n)

        lt?(n)
      end

      # Summary:
      #   name > other   =>  true, false, or nil
      # 
      # Same as +other < name+, see #<.
      def >(name)
        n = Name.create(name)

        n < self
      end

      # Summary:
      #   name <= other   =>  true, false, or nil
      # 
      # Returns true if +name+ is a subdomain of +other+ or is the same as
      # +other+. Returns <code>nil</code> if there's no relationship between
      # the two. 
      def <=(name)
        n = Name.create(name)
        self.equal?(n) || self < n
      end

      # Summary:
      #   name >= other   =>  true, false, or nil
      # 
      # Returns true if +name+ is an ancestor of +other+, or the two DNS names
      # are the same. Returns <code>nil</code> if there's no relationship
      # between the two. 
      def >=(name)
        n = Name.create(name)
        self.equal?(n) || self > n
      end

      # Summary:
      #     name <=> other   => -1, 0, +1, nil
      #  
      # Returns -1 if +name+ is a subdomain of +other+, 0 if
      # +name+ is the same as +other+, and +1 if +other+ is a subdomain of
      # +name+, or nil if +name+ has no relationship with +other+.
      def <=>(name)
        n = Name.create(name)

        return nil unless self.related?(n)

        return -1 if self.lt?(n)
        return +1 if n.lt?(self)
        # must be #equal?
        return  0
      end
    end

  end
end


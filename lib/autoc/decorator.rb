module AutoC


  module Decorator

    # attr_reader :prefix

    # Decorate identifier with type-specific prefix
    def decorate(id, **kws) = (@decorator.nil? ? Decorator.decorator : @decorator).(self, id, **kws)

    # Default behavior is to generate fully-qualified names for all unknown methods
    def method_missing(meth, *args) = args.empty? ? decorate(meth) : super

    # Pluggable CamelCase identifier decorator
    CAMEL_CASE = -> (type, symbol, abbreviate: false, **kws) {
      id = symbol.to_s.sub(/[!?]$/, '') # Strip trailing !?
      # Preserve trailing underscores
      /(.*?)(_*)$/.match(id)
      id = Regexp.last_match(1)
      trail = Regexp.last_match(2)
      _ = # Check for leading underscore
        if /^(_+)(.*)/ =~ id
          id = Regexp.last_match(2) # Chop leading underscore
          true
        else
          false
        end
      id = id[0] if abbreviate
      # Convert _separated_names to the CamelCase
      id = type.prefix + id.split('_').collect{ |s| s[0].upcase << s[1..-1] }.join
      # Carry over the method name's leading underscore only if the prefix is not in turn underscored
      (_ && !type.prefix.start_with?('_') ? Regexp.last_match(1) + id : id) + trail
    }

    # Pluggable _snake_case identifier decorator
    SNAKE_CASE = -> (type, symbol, abbreviate: false, **kws) {
      id = symbol.to_s.sub(/[!?]$/, '') # Strip trailing !?
      # Preserve trailing underscores
      /(.*?)(_*)$/.match(id)
      id = Regexp.last_match(1)
      trail = Regexp.last_match(2)
      # Check for leading underscore
      _ =
        if /^(_+)(.*)/ =~ id
          id = Regexp.last_match(2)
          true
        else
          false
        end
      id = abbreviate ? "#{type.prefix}#{id[0]}" : "#{type.prefix}_#{id}"
      # Carry over the method name's leading underscore only if the prefix is not in turn underscored
      (_ && !type.prefix.start_with?('_') ? Regexp.last_match(1) + id : id) + trail
    }

    def self.decorator=(decorator)
      @decorator = decorator
    end

    def self.decorator = @decorator

    self.decorator = CAMEL_CASE

  end # Decorator


end
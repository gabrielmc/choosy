module Choosy
  class Parser
    attr_reader :flags, :terminals, :command

    def initialize(command, lazy=nil, terminals=nil)
      @command = command
      @lazy = lazy || false
      @terminals = terminals || []

      @flags = {}
      return if command.options.nil?
      command.options.each do |o|
        verify_option(o)
      end
    end
    
    def parse!(argv, result=nil)
      index = 0
      result ||= ParseResult.new(@command, false)

      while index < argv.length
        case argv[index]
        when '-'
          if lazy?
            result.unparsed << '-'
            index += 1
          else
            raise Choosy::ParseError.new("Unfinished option '-'")
          end
        when '--'
          result.unparsed << '--' if lazy?
          index = parse_rest(argv, index, result)
        when /^-/
          index = parse_option(argv, index, result)
        else
          index = parse_arg(argv, index, result)
        end
      end

      result
    end

    def lazy?
      @lazy
    end

    private
    def verify_option(option)
      verify_flag(option, option.short_flag)
      verify_flag(option, option.long_flag)
      if option.negated?
        verify_flag(option, option.negated)
      end
    end

    def verify_flag(option, flag)
      return nil if flag.nil?
      if @flags[flag]
        raise Choosy::ConfigurationError.new("Duplicate option: '#{flag}'")
      end
      @flags[flag] = option
    end

    def parse_option(argv, index, result)
      current = argv[index]
      flag, arg = current.split("=", 2)
      option = @flags[flag]

      if option.nil?
        if lazy?
          result.unparsed << current
          return index + 1
        else
          raise Choosy::ParseError.new("Unrecognized option: '#{flag}'")
        end
      end

      if option.boolean?
        parse_boolean_option(result, option, index, arg, current, flag)
      elsif option.single?
        parse_single_option(result, option, index, argv, flag, arg)
      else # Vararg
        parse_multiple_option(result, option, index, argv, flag, arg)
      end
    end

    def parse_boolean_option(result, option, index, arg, current, flag)
      raise Choosy::ParseError.new("Argument given to boolean flag: '#{current}'") if arg
      if option.negated? && flag == option.negated
        result.options[option.name] = option.default_value
      else
        result.options[option.name] = !option.default_value 
      end
      index + 1
    end

    def parse_single_option(result, option, index, argv, flag, arg)
      if arg
        result.options[option.name] = arg
        index += 1
      else
        current, index = read_arg(argv, index + 1, result)
        if current.nil?
          raise Choosy::ParseError.new("Argument missing for option: '#{flag}'")
        else
          result.options[option.name] = current
        end
      end

      index
    end

    def parse_multiple_option(result, option, index, argv, flag, arg)
      if arg
        if option.arity.min > 1
          raise Choosy::ParseError.new("The '#{flag}' flag requires at least #{option.arity.min} arguments")
        end
        result.options[option.name] = arg
        return index + 1
      end

      index += 1
      min = index + option.arity.min
      max = index + option.arity.max
      args = []

      while index < min
        current, index = read_arg(argv, index, result)
        if current.nil?
          raise Choosy::ParseError.new("The '#{flag}' flag requires at least #{option.arity.min} arguments")
        end
        args << current
      end

      while index < max && index < argv.length
        current, index = read_arg(argv, index, result)
        break if current.nil?
        args << current
      end

      if index < argv.length && argv[index] == '-'
        index += 1
      end

      result.options[option.name] = args
      index
    end

    def parse_arg(argv, index, result)
      while index < argv.length
        current, index = read_arg(argv, index, result)
        break if current.nil?
        if lazy?
          result.unparsed << current
        else
          result.args << current
        end
      end
      index
    end

    def read_arg(argv, index, result)
      return [nil, index] if index >= argv.length

      current = argv[index]
      return [nil, index] if current =~ /^-/
      if @terminals.include? current
        result.unparsed.push(*argv[index, argv.length])
        return [nil, argv.length]
      end
      [current, index + 1]
    end

    def parse_rest(argv, index, result)
      index += 1
      if lazy?
        result.unparsed.push(*argv[index, argv.length])
      else
        result.args.push(*argv[index, argv.length])
      end
      argv.length
    end
  end
end

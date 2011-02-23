module Choosy
  class Option
    attr_accessor :name, :description
    attr_accessor :short_flag, :long_flag, :flag_parameter
    attr_accessor :cast_to,  :default_value
    attr_accessor :validation_step
    attr_accessor :arity
    attr_accessor :dependent_options

    def initialize(name)
      @name = name
    end
    
    def required=(req)
      @required = req
    end
    def required?
      @required == true
    end
  end
end

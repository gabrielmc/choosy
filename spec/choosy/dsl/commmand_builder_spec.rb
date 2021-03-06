module Choosy::DSL
  class FakeExecutor
    attr_reader :options, :args
    def execute!(options, args)
      @options = options
      @args = args
    end
  end

  describe CommandBuilder do
    before :each do
      @command = Choosy::Command.new(:cmd)
      @builder = @command.builder
    end

    describe :executor do
      it "should set the executor in the command" do
        @builder.executor FakeExecutor.new
        @command.executor.should be_a(FakeExecutor)
      end

      it "should handle proc arguments" do
        @builder.executor {|opts, args| puts "hi"}
        @command.executor.should_not be(nil)
      end

      it "should raise an error if the executor is nil" do
        attempting {
          @builder.executor nil
        }.should raise_error(Choosy::ConfigurationError, /executor was nil/)
      end

      it "should raise an error if the executor class doesn't have an 'execute!' method" do
        attempting {
          @builder.executor Array.new
        }.should raise_error(Choosy::ConfigurationError, /'execute!'/)
      end
    end#executor

    describe :arguments do
      it "should not fail if there is no block given" do
        attempting {
          @builder.arguments
        }.should_not raise_error
      end

      it "should pass in the block correctly" do
        @builder.arguments do
          metaname 'ARGS'
        end
        @command.arguments.metaname.should eql('ARGS')
      end

      it "should pass in the arguments to validate" do
        @builder.arguments do
          validate do |args, options|
            raise RuntimeError, "called"
          end
        end
        attempting {
          @command.arguments.validation_step.call([2, 2, 3], nil)
        }.should raise_error(RuntimeError, "called")
      end

      it "should finalize the arguments" do
        @builder.arguments do
          metaname 'args'
        end

        @builder.entity.arguments.cast_to.should eql(:string)
      end
    end#arguments
  end
end

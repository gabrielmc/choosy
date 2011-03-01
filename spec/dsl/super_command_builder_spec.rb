require 'spec_helpers'
require 'choosy/super_command'
require 'choosy/dsl/super_command_builder'

module Choosy::DSL
  describe SuperCommandBuilder do
    before :each do
      @command = Choosy::SuperCommand.new :superfoo
      @builder = @command.builder
    end

    describe :command do
      it "should add the command to the listing" do
        @builder.command :foo do |foo|
          foo.boolean :count, "The count"
        end

        @command.listing.should have(1).item
      end

      it "should add the command builder to the command_builders" do
        o = @builder.command :foo do |foo|
          foo.integer :size, "The size"
        end

        @command.command_builders[:foo].should be(o.builder)
      end

      it "should finalize the builder for the command" do
        o = @builder.command :foo
        o.printer.should_not be(nil)
      end

      it "should be able to accept a new command as an argument" do
        cmd = Choosy::Command.new :cmd do |c|
          c.float :float, "Float"
        end
        @builder.command cmd
        @command.listing[0].should be(cmd)
      end
    end

    describe :help do
      it "should create a help command when asked" do
        h = @builder.help
        @command.listing[0].should be(h)
      end

      it "should set the default summary of the help command" do
        h = @builder.help
        h.summary.should match(/Show the info/)
      end

      it "should st the summary of the command when given" do
        h = @builder.help "Show this help message"
        h.summary.should match(/Show this/)
      end

      describe "when validated" do
        it "should return the super command name when called without arguments" do
          h = @builder.help
          attempting {
            h.argument_validation.call([])
          }.should raise_error(Choosy::HelpCalled, :superfoo)
        end

        it "should return the name of the first argument when called, as a symbol" do
          h = @builder.help
          attempting {
            h.argument_validation.call(['foo'])
          }.should raise_error(Choosy::HelpCalled, :foo)
        end
      end
    end
  end
end
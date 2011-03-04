require 'spec_helpers'
require 'choosy/dsl/base_command_builder'
require 'choosy/command'

module Choosy::DSL
  describe BaseCommandBuilder do
    before :each do
      @command = Choosy::Command.new(:cmd)
      @builder = @command.builder
    end

    describe :printer do
      it "should raise an error on a non-standard printer" do
        attempting {
          @builder.printer :non_standard
        }.should raise_error(Choosy::ConfigurationError, /Unknown printing/)
      end
      
      it "should know how to set the default printer" do
        @builder.printer :standard
        @command.printer.should be_a(Choosy::Printing::HelpPrinter)
      end

      it "should know how to turn off color" do
        @builder.printer :standard, :color => false
        @command.printer.color.disabled?.should be(true)
      end

      it "should know how to set the maximum width" do
        @builder.printer :standard, :max_width => 70
        @command.printer.columns.should eql(70)
      end

      it "should know how to set the header attributes" do
        @builder.printer :standard, :headers => [:bold, :blue]
        @command.printer.header_attrs.should eql([:bold, :blue])
      end

      it "should be able to set multiple properties of the printer" do
        @builder.printer :standard, :max_width => 25, :headers => [:bold, :red], :color => false
        @command.printer.color.should be_disabled
        @command.printer.header_attrs.should eql([:bold, :red])
      end
      
      class TestPrinter
        def print!(cmd)
        end
      end 

      it "should understand how to set custom printers" do
        attempting {
          @builder.printer TestPrinter.new
        }.should_not raise_error
      end

      it "should fail when the printer doesn't implement 'print!'" do
        attempting {
          @builder.printer "this"
        }.should raise_error(Choosy::ConfigurationError, /Unknown printing/)
      end

      describe "for :erb printing" do
        it "should be able to handle a given template" do
          @builder.printer :erb, :template => __FILE__
          @command.printer.should be_a(Choosy::Printing::ERBPrinter)
        end

        it "should fail when the tempate file doesn't exist" do
          attempting {
            @builder.printer :erb, :template => "non"
          }.should raise_error(Choosy::ConfigurationError, /template file doesn't exist/)
        end

        it "should fail when no template option is specified" do
          attempting {
            @builder.printer :erb
          }.should raise_error(Choosy::ConfigurationError, /no template/)
        end
      end
    end#printer

    describe :summary do
      it "should set the summary for this command" do
        @builder.summary "This is a summary"
        @command.summary.should eql("This is a summary")
      end
    end#summary

    describe :header do
      it "should set a header for this command" do
        @builder.header 'HEADER'
        @command.listing[0].value.should eql('HEADER')
      end

      it "should set the attributes of the header effectively" do
        @builder.header 'HEADER', :bold, :blue
        @command.listing[0].attrs.should eql([:bold, :blue])
      end
    end#header

    describe :para do
      it "should add a paragraph to the list of options for printing" do
        @builder.para 'Required arguments'
        @command.listing[0].value.should eql('Required arguments')
      end

      it "should leave the paragraph without attributes" do
        @builder.para 'No attributes'
        @command.listing[0].attrs.should eql([])
      end

      it "should add an empty string to the listing when called with no arguments" do
        @builder.para
        @command.listing[0].value.should be(nil)
      end

      it "should add attributes to the paragraph" do
        @builder.para 'Here', :bold, :red
        @command.listing[0].attrs.should eql([:bold, :red])
      end
    end#para

    describe :option do
      describe "when using just a name" do
        it "should set the name of the option" do
          o = @builder.option :opto do |o|
            o.short '-o'
          end
          o.name.should eql(:opto)
        end

        it "should handle a CommandBuilder block" do
          @builder.option :opto do |o|
            o.short '-s'
            o.should be_a(OptionBuilder)
          end
        end

        it "should fail when no block is given" do
          attempting {
            @builder.option "blah"
          }.should raise_error(Choosy::ConfigurationError, /No configuration block/)
        end

        it "should fail when the symbol is nil" do
          attempting {
            @builder.option nil do |o|
              o.short = '-o'
            end
          }.should raise_error(Choosy::ConfigurationError, /The option name was nil/)
        end
      end

      describe "when using a hash" do
        describe "for dependencies" do
          it "should set the dependencies of that option" do
            o = @builder.option :o => [:s] do |o|
              o.short '-o'
            end
            o.dependent_options.should have(1).item
            o.dependent_options[0].should eql(:s)
          end
        end
        
        describe "for options" do
          it "should set the name of the option" do 
            o = @builder.option :o => {:short => '-o'}
            o.name.should eql(:o)
          end

          it "should set the properties via the hash" do
            o = @builder.option :o => {:short => '-o'}
            o.short_flag.should eql('-o')
          end

          it "should still accept the block" do
            o = @builder.option :o => {:short => '-o'} do |s|
              s.desc "short"
            end
            o.description.should eql('short')
          end
        end

        describe "whose arguments are invalid" do
          it "should fail when more than one key is present" do
            attempting {
              @builder.option({:o => nil, :p => nil})
            }.should raise_error(Choosy::ConfigurationError, /Malformed option hash/)
          end

          it "should fail when more than the hash is empty" do
            attempting {
              @builder.option({})
            }.should raise_error(Choosy::ConfigurationError, /Malformed option hash/)
          end

          it "should fail when the option value is not an Array or a Hash" do
            attempting {
              @builder.option({:o => :noop})
            }.should raise_error(Choosy::ConfigurationError, "Unable to process option hash")
          end
        end

        describe "after the option block has been processed" do
          it "should call the 'finalize!' method on the builder" do
            o = @builder.option :o do |o|
              o.short '-o'
            end
            o.cast_to.should eql(:boolean)
          end

          it "should add the builder with the given name to the command option_builders hash" do
            @builder.option :o => {:short => '-l'}
            @builder.command.option_builders.should have(1).item
          end

          it "adds the option to the listing" do
            @builder.option :o => {:short => '-l'}
            @builder.command.listing.should have(1).item
            @builder.command.listing[0].name.should eql(:o)
          end
        end
      end
    end#option

    describe :boolean do
      it "should be able to set short flag" do
        o = @builder.boolean :Debug, "Show the debug output"
        o.short_flag.should eql('-D')
      end

      it "should be able to set the long flag" do
        o = @builder.boolean :Debug, "show debug"
        o.long_flag.should eql('--debug')
      end

      it "should be able to fix the naming convention for long names" do
        o = @builder.boolean :no_COLOR, "No color output"
        o.long_flag.should eql('--no-color')
      end

      it "should set the description" do
        o = @builder.boolean :no_color, "No color output"
        o.description.should eql("No color output")
      end

      it "should handle optional configuration" do
        o = @builder.boolean :debug, "Debug", {:short => '-D'}
        o.short_flag.should eql('-D')
      end

      it "should be able to capture block level data" do
        o = @builder.boolean :debug, "Show debug output" do |d|
          d.short '-D'
        end
        o.short_flag.should eql("-D")
      end

      it "should suppress the short flag for boolean_" do
        o = @builder.boolean_ :debug, "Show debug output"
        o.short_flag.should be(nil)
      end
    end#boolean

    describe :single do
      it "should be able to set the short flag" do
        o = @builder.single :count, "Show the count"
        o.short_flag.should eql('-c')
      end

      it "should be able to set the metaname name" do
        o = @builder.single :count, "Show the count"
        o.metaname.should eql('COUNT')
      end
    end#single

    describe :multiple do
      it "should be able to set the short flag" do
        o = @builder.multiple :file_names, "The file names"
        o.short_flag.should eql('-f')
      end

      it "should be able to set the metaname name" do
        o = @builder.multiple :file_names, "The file names"
        o.metaname.should eql('FILE_NAMES+')
      end

      it "should be able to yield a block" do
        o = @builder.multiple :file_names, "The file names" do |f|
          f.long '--files'
        end
        o.long_flag.should eql('--files')
      end
    end#multiple

    describe "dynamically generated method for" do
      Choosy::Converter::CONVERSIONS.keys.each do |method|
        it "#{method}" do
          o = @builder.send(method, method, "Desc of #{method}")
          o.cast_to.should eql(Choosy::Converter.for(method))
          if o.cast_to == :boolean
            o.metaname.should be(nil)
          else
            o.metaname.should eql(method.to_s.upcase)
          end
        end

        it "#{method}_" do
          underscore = "#{method}_".to_sym
          o = @builder.send(underscore, method, "Desc of #{method}_")
          o.short_flag.should be(nil)
        end
        
        next if method == :boolean || method == :bool

        it "#{method}s" do
          plural = "#{method}s".to_sym
          o = @builder.send(plural, plural, "Desc of #{plural}")
          o.cast_to.should eql(Choosy::Converter.for(method))
          o.metaname.should eql("#{plural.to_s.upcase}+")
        end

        it "#{method}s_" do
          underscore = "#{method}s_".to_sym
          o = @builder.send(underscore, method, "Desc of #{method}s_")
          o.short_flag.should be(nil)
        end
      end
    end

    describe :version do
      it "should allow you to set the message" do
        v = @builder.version 'blah'
        attempting {
          v.validation_step.call
        }.should raise_error(Choosy::VersionCalled, 'blah')
      end

      it "should allow you to use a block to alter the help message" do
        v = @builder.version 'blah' do |v|
          v.desc "Version"
        end
        v.description.should eql("Version")
      end

      it "should set the message automatically" do
        v = @builder.version "blah"
        v.description.should eql("The version number")
      end
    end#version

    describe :finalize! do
      it "should set the printer if not already set" do
        @builder.finalize!
        @command.printer.should be_a(Choosy::Printing::HelpPrinter)
      end
    end#finalize!
  end
end
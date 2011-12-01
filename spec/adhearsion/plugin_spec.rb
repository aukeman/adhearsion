require 'spec_helper'

include InitializerStubs

describe Adhearsion::Plugin do

  describe "inheritance" do
    after do
      defined?(FooBar) and Object.send(:remove_const, :"FooBar")
    end

    it "should provide the plugin name in a plugin class" do
      ::FooBar = Class.new Adhearsion::Plugin
      ::FooBar.plugin_name.should == "foo_bar"
    end

    it "should provide the plugin name in a plugin instance" do
      ::FooBar = Class.new Adhearsion::Plugin
      ::FooBar.new.plugin_name.should == "foo_bar"
    end

    it "should provide a setter for plugin name" do
      ::FooBar = Class.new Adhearsion::Plugin do
        self.plugin_name = "bar_foo"
      end

      ::FooBar.plugin_name.should == "bar_foo"
    end
  end

  describe "metaprogramming" do
    Adhearsion::Plugin::SCOPE_NAMES.each do |method|
      it "should respond to #{method.to_s}" do
        Adhearsion::Plugin.should respond_to method
      end

      it "should respond to #{method.to_s}_module" do
        Adhearsion::Plugin.should respond_to "#{method.to_s}_module"
      end
    end
  end

  [:rpc, :dialplan, :console].each do |method|

    describe "extending an object with #{method.to_s} scope methods" do
      
      before(:all) do
        A = Class.new do
          def bar
            "bar"
          end
        end
      end

      after(:all) do
        defined?(A) and Object.send(:remove_const, :"A")
      end

      before do
        FooBar = Class.new Adhearsion::Plugin do
          self.method(method).call(:foo) do
            "foo".concat bar
          end

        end
        flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
        Adhearsion::Plugin.load
        Adhearsion::Plugin.send("#{method.to_s}_module".to_sym).instance_methods.map{|x| x.to_s}.include?("foo").should == true
      end
      
      after  do
        defined?(FooBar) and Object.send(:remove_const, :"FooBar")
      end

      describe "when extending a Class" do
        it "should respond to any of the #{method.to_s} scope methods and have visibility to the own instance methods" do
          
          Adhearsion::Plugin.send("add_#{method}_methods".to_sym, A)
          a = A.new
          a.should respond_to :foo
          a.foo.should == "foobar"
        end
      end
      
      describe "when extending an instance" do
        it "should respond to any of the scope methods and have visibility to the own instance methods" do

          a = A.new
          Adhearsion::Plugin.send("add_#{method}_methods".to_sym, a)
          a.should respond_to :foo
          a.foo.should == "foobar"
        end
      end
    end
  end

  describe "While adding console methods" do

    it "should add a new method to Console" do
      FooBar = Class.new Adhearsion::Plugin do
        console :config do
          Adhearsion.config
        end
      end
      flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
      Adhearsion::Plugin.load
      Adhearsion::Console.should respond_to(:config)
      Adhearsion::Console.config.should == Adhearsion.config
    end
  end

  describe "While configuring plugins" do
    after(:each) do
      defined?(FooBar) and Object.send(:remove_const, :"FooBar")
    end

    subject {
      Class.new Adhearsion::Plugin do
        config :bar_foo do
          name     "user"     , :desc => "name to authenticate user"
          password "password" , :desc => "authentication password"
          host     "localhost", :desc => "valid IP or hostname"
        end
      end
    }

    its(:plugin_name) { should == :bar_foo }

    its(:config) { should be_instance_of Loquacious::Configuration }

    it "should keep a default configuration and a description" do
      [:name, :password, :host].each do |value|
        subject.config.should respond_to value
      end

      subject.config.name.should     == "user"
      subject.config.password.should == "password"
      subject.config.host.should     == "localhost"
    end

    it "should return a description of configuration options" do
      subject.show_description.should be_kind_of Loquacious::Configuration::Help
    end

    describe "while updating config values" do
      it "should return the updated value" do
        subject.config.name = "usera"
        subject.config.name.should == "usera"
      end
    end

  end

  describe "add and delete on the air" do
    it "should add plugins on the air" do
      Adhearsion::Plugin.delete_all
      Adhearsion::Plugin.add AhnPluginDemo
      Adhearsion::Plugin.count.should eql 1
    end

    it "should delete plugins on the air" do
      Adhearsion::Plugin.delete_all
      Adhearsion::Plugin.add AhnPluginDemo
      Adhearsion::Plugin.count.should eql 1
      Adhearsion::Plugin.delete AhnPluginDemo
      Adhearsion::Plugin.count.should eql 0
    end
  end

  describe "#count" do
    after(:each) do
      defined?(FooBar) and Object.send(:remove_const, :"FooBar")
    end

    it "should count the number of registered plugins" do
      number = Adhearsion::Plugin.count
      FooBar = Class.new Adhearsion::Plugin
      Adhearsion::Plugin.count.should eql(number + 1)
    end
  end

  describe "Adhearsion::Plugin.load" do
    before do
      Adhearsion::Plugin.class_eval do
        def self.reset_methods_scope
          @methods_scope = Hash.new { |hash, key| hash[key] = Module.new }
        end

        def self.reset_subclasses
          @subclasses = nil
        end
      end

      Adhearsion::Plugin.reset_methods_scope
      Adhearsion::Plugin.reset_subclasses
    end

    after do
      Adhearsion::Plugin.initializers.clear
      defined?(FooBar) and Object.send(:remove_const, :"FooBar")
      defined?(FooBarBaz) and Object.send(:remove_const, :"FooBarBaz")
      defined?(FooBarBazz) and Object.send(:remove_const, :"FooBarBazz")
    end

    describe "while registering plugins initializers" do
      it "should do nothing with a Plugin that has no init method call" do
        FooBar = Class.new Adhearsion::Plugin

        # 1 => Punchblock. Must be empty once punchblock initializer is an external Plugin
        Adhearsion::Plugin.initializers.should have(1).initializers
        flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
        Adhearsion::Plugin.load
      end

      it "should add a initializer when Plugin defines it" do
        FooBar = Class.new Adhearsion::Plugin do
          init :foo_bar do
            FooBar.log "foo bar"
          end
          def self.log
          end
        end

        flexmock(FooBar).should_receive(:log).once
        Adhearsion::Plugin.initializers.length.should be 1
        flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
        Adhearsion::Plugin.load
      end

      it "should initialize all Plugin childs, including deep childs" do
        FooBar = Class.new Adhearsion::Plugin do
          init :foo_bar do
            FooBar.log "foo bar"
          end

          def self.log
          end
        end

        FooBarBaz = Class.new FooBar do
          init :foo_bar_baz do
            FooBar.log "foo bar baz"
          end
        end
        FooBarBazz = Class.new FooBar do
          init :foo_bar_bazz do
            FooBar.log "foo bar bazz"
          end
        end

        flexmock(FooBar).should_receive(:log).times(3)
        flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
        Adhearsion::Plugin.load
      end

      it "should allow to include an initializer before another one" do
        FooBar = Class.new Adhearsion::Plugin do
          init :foo_bar do
            FooBar.log "foo bar"
          end

          def self.log
          end
        end

        FooBarBaz = Class.new FooBar do
          init :foo_bar_baz, :before => :foo_bar do
            FooBar.log "foo bar baz"
          end
        end

        Adhearsion::Plugin.initializers.tsort.first.name.should eql :foo_bar_baz
        Adhearsion::Plugin.initializers.tsort.last.name.should eql :foo_bar
      end

      it "should allow to include an initializer after another one" do
        FooBar = Class.new Adhearsion::Plugin do
          init :foo_bar do
            FooBar.log "foo bar"
          end

          def self.log
          end
        end

        FooBarBaz = Class.new FooBar do
          init :foo_bar_baz, :after => :foo_bar_bazz do
            FooBar.log "foo bar baz"
          end
        end

        FooBarBazz = Class.new FooBar do
          init :foo_bar_bazz do
            FooBar.log "foo bar bazz"
          end
        end

        Adhearsion::Plugin.initializers.length.should eql 3
        Adhearsion::Plugin.initializers.tsort.first.name.should eql :foo_bar
        Adhearsion::Plugin.initializers.tsort.last.name.should eql :foo_bar_baz
      end
    end

    [:rpc, :dialplan].each do |method|
      describe "Plugin subclass with #{method.to_s}_method definition" do
        it "should add a method defined using #{method.to_s} method" do
          FooBar = Class.new Adhearsion::Plugin do
            self.method(method).call(:foo)

            def self.foo(call)
              "bar"
            end
          end

          flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
          Adhearsion::Plugin.load
          Adhearsion::Plugin.methods_scope[method].instance_methods.map{|x| x.to_s}.include?(:foo.to_s).should be true
        end

        it "should add a method defined using #{method.to_s} method with a block" do
          FooBar = Class.new Adhearsion::Plugin do
            block = lambda{|call| "bar"}
            self.method(method).call(:foo, &block)
          end

          flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
          Adhearsion::Plugin.load
          Adhearsion::Plugin.methods_scope[method].instance_methods.map{|x| x.to_s}.include?(:foo.to_s).should be true
        end

        it "should add an instance method defined using #{method.to_s} method" do
          FooBar = Class.new Adhearsion::Plugin do
            self.method(method).call(:foo)
            def foo(call)
              call
            end
          end

          flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
          Adhearsion::Plugin.load
          Adhearsion::Plugin.methods_scope[method].instance_methods.map{|x| x.to_s}.include?(:foo.to_s).should be true
        end

        it "should add an array of methods defined using #{method.to_s} method" do
          FooBar = Class.new Adhearsion::Plugin do
            self.method(method).call([:foo, :bar])

            def self.foo(call)
              call
            end

            def self.bar(call)
              "foo"
            end
          end

          flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
          Adhearsion::Plugin.load
          [:foo, :bar].each do |_method|
            Adhearsion::Plugin.methods_scope[method].instance_methods.map{|x| x.to_s}.include?(_method.to_s).should be true
          end
          Adhearsion::Plugin.methods_scope[method].instance_methods.length.should eql 2
        end

        it "should add an array of instance methods defined using #{method.to_s} method" do
          FooBar = Class.new Adhearsion::Plugin do
            self.method(method).call([:foo, :bar])
            def foo(call)
              call
            end

            def bar(call)
              call
            end
          end

          flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
          Adhearsion::Plugin.load
          [:foo, :bar].each do |_method|
            Adhearsion::Plugin.methods_scope[method].instance_methods.map{|x| x.to_s}.include?(_method.to_s).should be true
          end
        end

        it "should add an array of instance and singleton methods defined using #{method.to_s} method" do
          FooBar = Class.new Adhearsion::Plugin do
            self.method(method).call([:foo, :bar])
            def self.foo(call)
              call
            end

            def bar(call)
              call
            end
          end

          flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
          Adhearsion::Plugin.load
          [:foo, :bar].each do |_method|
            Adhearsion::Plugin.methods_scope[method].instance_methods.map{|x| x.to_s}.include?(_method.to_s).should be true
          end
        end

        it "should add a method defined using #{method.to_s} method with a specific block" do
          FooBar = Class.new Adhearsion::Plugin do
            self.method(method).call(:foo) do
              "foo"
            end
          end

          flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
          Adhearsion::Plugin.load
          Adhearsion::Plugin.methods_scope[method].instance_methods.map{|x| x.to_s}.include?(:foo.to_s).should be true
          Adhearsion::Plugin.send("#{method.to_s}_module".to_sym).instance_methods.map{|x| x.to_s}.include?(:foo.to_s).should be true
        end
      end
    end

    describe "Plugin subclass with rpc_method and dialplan_method definitions" do
      it "should add a method defined using rpc and a method defined using dialplan" do
        FooBar = Class.new Adhearsion::Plugin do
          rpc :foo
          dialplan :foo

          def self.foo(call)
            "bar"
          end
        end

        flexmock(Adhearsion::PunchblockPlugin::Initializer).should_receive(:start).and_return true
        Adhearsion::Plugin.load
        [:dialplan_module, :rpc_module].each do |_module|
          Adhearsion::Plugin.send(_module).instance_methods.map{|x| x.to_s}.include?(:foo.to_s).should be true
        end
      end
    end
  end  
end
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Registry do
  before :each do
    Registry.clear
  end

  describe "#add_hook" do
    it "does not allow multiple hooks with the same name" do
      Registry.add_hook(:test, :hook, "test_callback", "value1")
      lambda { Registry.add_hook(:test, :hook, "test_callback", "value2") }.should raise_error(/Cannot redefine callback/)

      Registry.each_hook(:test, :hook) do |callback|
        callback.should == "value1"
      end
    end

    it "does not allow both a value and a block to be specified" do
      lambda { Registry.add_hook(:test, :hook, "test_callback", "inline_value") { "block_value" } }.should raise_error(/Cannot pass both a value and a block/)
      hooks = []
      Registry.each_hook(:test, :hook) do |callback|
        hooks << callback
      end
      hooks.should be_empty
    end

    it "adds the given callback to the registry" do
      Registry.add_hook(:test, :hook, "0_block_callback") { "my block" }
      Registry.add_hook(:test, :hook, "1_value_callback", "foo bar baz")

      hooks = []
      Registry.each_hook(:test, :hook) do |callback|
        hooks << callback
      end
      hooks.first.should be_a(Proc)
      hooks.first.call.should == "my block"
      hooks.last.should == "foo bar baz"
    end
  end

  describe "#each_hook" do
    it "does nothing if the hook has no callbacks" do
      lambda do
        Registry.each_hook(:test, :nonexistent) do |callback|
          raise "each_hook should not have yielded anything"
        end
      end.should_not raise_error
    end

    it "yields each hook in order" do
      Registry.add_hook(:test, :hook, "2_callback", "second")
      Registry.add_hook(:test, :hook, "3_callback", "third")
      Registry.add_hook(:test, :hook, "1_callback", "first")
      
      values = []

      Registry.each_hook(:test, :hook) do |value|
        values << value
      end

      values.should == ["first", "second", "third"]
    end

    it "yields procs intact, not their values" do
      Registry.add_hook(:test, :hook, "my_callback") { "my_callback_value" }
      Registry.add_hook(:test, :hook, "my_other_callback") { "my_other_callback_value" }

      blocks = []
      Registry.each_hook(:test, :hook) do |block|
        blocks << block
      end

      blocks.map(&:class).should == [Proc, Proc]
      blocks.map(&:call).should == ["my_callback_value", "my_other_callback_value"]
    end
  end

  describe "#find_first_hook" do
    it "returns the value returned by the first hook which returns a value" do
      Registry.add_hook(:test, :hook, "0_callback") { 0 }
      Registry.add_hook(:test, :hook, "1_callback") { 1 }
      Registry.add_hook(:test, :hook, "2_callback") { 2 }

      Registry.find_first_hook(:test, :hook) do |callback|
        val = callback.call
        val.odd? ? val.ordinalize : nil
      end.should == "1st"
    end
  end
end

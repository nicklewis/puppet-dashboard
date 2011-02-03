class Registry
  class << self
    delegate :add_hook, :each_hook, :find_first_hook, :hooks, :to => :instance
  end

  def self.clear
    @instance = nil
  end

  def self.instance
    @instance ||= new
  end

  def add_hook( feature_name, hook_name, callback_name, value = nil, &block )
    if block and value
      raise "Cannot pass both a value and a block to add_hook" 
    elsif @registry[feature_name][hook_name][callback_name]
      raise "Cannot redefine callback [#{feature_name.inspect},#{hook_name.inspect},#{callback_name}]"
    end

    @registry[feature_name][hook_name][callback_name] = value || block
  end

  def each_hook( feature_name, hook_name )
    hook = @registry[feature_name][hook_name]
    hook.sort.each do |callback_name,callback|
      yield( callback )
    end
    nil
  end

  def find_first_hook(feature_name, hook_name)
    self.each_hook(feature_name, hook_name) do |thing|
      if result = yield(thing)
        return result
      end
    end
    nil
  end

  private

  def initialize
    @registry = Hash.new do |registry, feature_name|
      registry[feature_name] = Hash.new do |hooks, hook_name|
        hooks[hook_name] = Hash.new
      end
    end
  end
end

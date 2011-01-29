module Registry
  @registry = Hash.new do |registry, feature_name|
    registry[feature_name] = Hash.new do |hooks, hook_name|
      hooks[hook_name] = Hash.new
    end
  end

  def self.each_hook( feature_name, hook_name )
    hook = @registry[feature_name][hook_name]
    hook.keys.sort.each do |callback_name|
      yield( hook[callback_name] )
    end
  end

  def self.add_hook( feature_name, hook_name, callback_name, value = nil, &block )
    if block
      raise "Cannot pass both a value and a block to add_hook" if value
      value = block
    end
    @registry[feature_name][hook_name][callback_name] = value
  end

  def self.find_first_hook(feature_name, hook_name)
    self.each_hook(feature_name, hook_name) do |thing|
      if result = yield(thing)
        return result
      end
    end
    nil
  end
end

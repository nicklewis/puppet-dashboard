require File.expand_path(File.join(File.dirname(__FILE__), *%w[.. spec_helper]))

describe Node do
  describe 'attributes' do
    before :each do
      Node.generate!
      @node = Node.new
    end

    it { should have_many(:node_class_memberships) }
    it { should have_many(:node_classes).through(:node_class_memberships) }
    it { should have_many(:node_group_memberships) }
    it { should have_many(:node_groups).through(:node_group_memberships) }

    it { should have_db_column(:name).of_type(:string) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }

  end

  describe "statuses" do
    before :each do
      later = 1.week.ago.to_date
      sooner = Date.today

      @ever_changed = Node.generate!(:name => 'ever_changed').tap do |node|
        Report.generate!(:host => node.name, :time => later, :status => 'changed')
        Report.generate!(:host => node.name, :time => sooner, :status => 'changed')
        node.reload
      end

      @ever_unchanged = Node.generate!(:name => 'ever_unchanged').tap do |node|
        Report.generate!(:host => node.name, :time => later, :status => 'unchanged')
        Report.generate!(:host => node.name, :time => sooner, :status => 'unchanged')
        node.reload
      end

      @just_changed = Node.generate!(:name => 'just_changed').tap do |node|
        Report.generate!(:host => node.name, :time => later, :status => 'failed')
        Report.generate!(:host => node.name, :time => sooner, :status => 'changed')
        node.reload
      end

      @just_unchanged = Node.generate!(:name => 'just_unchanged').tap do |node|
        Report.generate!(:host => node.name, :time => later, :status => 'failed')
        Report.generate!(:host => node.name, :time => sooner, :status => 'unchanged')
        node.reload
      end

      @ever_failed = Node.generate!(:name => 'ever_failed').tap do |node|
        Report.generate!(:host => node.name, :time => later, :status => 'failed')
        Report.generate!(:host => node.name, :time => sooner, :status => 'failed')
        node.reload
      end

      @just_failed = Node.generate!(:name => 'just_failed').tap do |node|
        Report.generate!(:host => node.name, :time => later, :status => 'unchanged')
        Report.generate!(:host => node.name, :time => sooner, :status => 'failed')
        node.reload
      end

      @never_reported = Node.generate!(:name => 'never_reported')
    end

    [
      [true,  true,  %w[ever_changed ever_unchanged just_changed just_unchanged]],
      [true,  false, %w[ever_failed just_failed]],
      [false, true,  %w[ever_changed ever_unchanged just_changed just_unchanged just_failed]],
      [false, false, %w[just_changed just_unchanged ever_failed just_failed]],
    ].each do |currentness, successfulness, inclusions|
      context "when #{currentness ? 'current' : 'ever'} and #{successfulness ? 'successful' : 'failed'}" do
        let(:currentness) { currentness }
        let(:successfulness) { successfulness }
        let(:inclusions) { inclusions }

        describe "::by_currentness_and_successfulness" do
          it "should exactly match: #{inclusions.join(', ')}" do
            Node.by_currentness_and_successfulness(currentness, successfulness).map(&:name).sort.should == inclusions.sort
          end
        end
      end
    end
  end

  describe "::find_from_inventory_search" do
    before :each do
      @foo = Node.generate :name => "foo"
      @bar = Node.generate :name => "bar"
    end

    it "should find the nodes that match the list of names given" do
      PuppetHttps.stubs(:get).returns('["foo", "bar"]')
      Node.find_from_inventory_search('').should =~ [@foo, @bar]
    end

    it "should create nodes that don't exist" do
      PuppetHttps.stubs(:get).returns('["foo", "bar", "baz"]')
      Node.find_from_inventory_search('').map(&:name).should =~ ['foo', 'bar', 'baz']
    end

    it "should look-up nodes case-insensitively" do
      baz = Node.generate :name => "BAZ"
      PuppetHttps.stubs(:get).returns('["foo", "BAR", "baz"]')
      Node.find_from_inventory_search('').should =~ [@foo, @bar, baz]
    end
  end

  describe ".reported" do
    it "should return all nodes with a latest report" do
      unreported_node = Node.generate
      reported_node = Node.generate
      Report.generate!(:host => reported_node.name)

      Node.reported.should == [reported_node]
    end
  end

  describe ".unreported" do
    it "should return all nodes whose latest report was unreported" do
      unreported_node = Node.generate
      reported_node = Node.generate
      Report.generate!(:host => reported_node.name)

      Node.unreported.should == [unreported_node]
    end
  end

  describe "no_longer_reporting" do
    it "should return all nodes whose latest report is more than 1 hour ago" do
      SETTINGS.expects(:no_longer_reporting_cutoff).at_least_once.returns(1.hour.to_i)
      old = node = Node.generate(:reported_at => 2.hours.ago, :name => "old")
      new = node = Node.generate(:reported_at => 10.minutes.ago, :name => "new")

      Node.no_longer_reporting.should include(old)
      Node.no_longer_reporting.should_not include(new)
    end
  end

  describe "" do
    before :each do
      @nodes = {:hidden   => Node.generate!(:hidden => true),
                :unhidden => Node.generate!(:hidden => false)
      }
    end

    [:hidden, :unhidden].each do |hiddenness|
      describe hiddenness do
        it "should find all #{hiddenness} nodes" do
          nodes = Node.send(hiddenness)
          nodes.length.should == 1
          nodes.first.should == @nodes[hiddenness]
        end
      end
    end
  end

  describe 'when computing a configuration' do
    before :each do
      @node = Node.generate!
    end

    it 'should return a name and set of classes and parameters' do
      @node.configuration.keys.sort.should == ['classes', 'name', 'parameters']
    end

    it "should return the names of the node's classes in the returned class list" do
      @node.node_classes = @classes = Array.new(3) { NodeClass.generate! }
      @node.configuration['classes'].sort.should == @classes.collect(&:name).sort
    end

    it "should return the node's compiled parameters in the returned parameters list" do
      @node.stubs(:compiled_parameters).returns [
        OpenStruct.new(:name => 'a', :value => 'b', :sources => Set[:foo]),
        OpenStruct.new(:name => 'c', :value => 'd', :sources => Set[:bar])
      ]
      @node.configuration['parameters'].should == { 'a' => 'b', 'c' => 'd' }
    end
  end

  describe "#parameters=" do
    before { @node = Node.generate! }

    it "should create parameter objects for new parameters" do
      lambda {
        @node.parameter_attributes = [{:key => :key, :value => :value}]
        @node.save
      }.should change(Parameter, :count).by(1)
    end

    it "should create and destroy parameters based on updated parameters" do
      @node.parameter_attributes = [{:key => :key1, :value => :value1}]
      lambda {
        @node.parameter_attributes = [{:key => :key2, :value => :value2}]
        @node.save
      }.should_not change(Parameter, :count)
    end

    it "should create timeline events for creation and destruction" do
      @node.parameter_attributes = [{:key => :key1, :value => :value1}]
      lambda {
        @node.parameter_attributes = [{:key => :key2, :value => :value2}]
        @node.save
      }.should change(TimelineEvent, :count).by_at_least(2)
    end
  end

  describe "handling the node group graph" do
    before :each do
      @node = Node.generate! :name => "Sample"

      @node_group_a = NodeGroup.generate! :name => "A"
      @node_group_b = NodeGroup.generate! :name => "B"

      @param_1 = Parameter.generate(:key => 'foo', :value => '1')
      @param_2 = Parameter.generate(:key => 'bar', :value => '2')

      @node_group_a.parameters << @param_1
      @node_group_b.parameters << @param_2

      @node.node_groups << @node_group_a
      @node.node_groups << @node_group_b
    end

    describe "when a group is included twice" do
      before :each do
        @node_group_c = NodeGroup.generate! :name => "C"
        @node_group_d = NodeGroup.generate! :name => "D"
        @node_group_c.node_groups << @node_group_d
        @node_group_a.node_groups << @node_group_c
        @node_group_b.node_groups << @node_group_c
      end

      it "should return the correct groups and sources" do
        @node.node_groups_with_sources.should == {@node_group_a => Set[@node], @node_group_c => Set[@node_group_a,@node_group_b], @node_group_b => Set[@node], @node_group_d => Set[@node_group_c]}
      end
    end

    describe "handling parameters in the graph" do

      it "should return the compiled parameters" do
        @node.compiled_parameters.should == [
          OpenStruct.new(:name => 'foo', :value => '1', :sources => Set[@node_group_a]),
          OpenStruct.new(:name => 'bar', :value => '2', :sources => Set[@node_group_b])
        ]
      end

      it "should ensure that parameters nearer to the node are retained" do
        @node_group_a1 = NodeGroup.generate!
        @node_group_a1.parameters << Parameter.create(:key => 'foo', :value => '2')
        @node_group_a.node_groups << @node_group_a1

        @node.compiled_parameters.should == [
          OpenStruct.new(:name => 'foo', :value => '1', :sources => Set[@node_group_a]),
          OpenStruct.new(:name => 'bar', :value => '2', :sources => Set[@node_group_b])
        ]
      end

      it "should raise an error if there are parameter conflicts among children" do
        @param_2.update_attribute(:key, 'foo')

        lambda {@node.compiled_parameters}.should raise_error(ParameterConflictError)
        @node.errors.on(:parameters).should == "foo"
      end

      it "should not raise an error if there are two sibling parameters with the same key and value" do
        @param_2.update_attributes(:key => @param_1.key, :value => @param_1.value)

        lambda {@node.compiled_parameters}.should_not raise_error(ParameterConflictError)
        @node.errors.on(:parameters).should be_nil
      end

      it "should not raise an error if there are parameter conflicts that can be resolved at a higher level" do
        @param_3 = Parameter.generate(:key => 'foo', :value => '3')
        @param_4 = Parameter.generate(:key => 'foo', :value => '4')
        @node_group_c = NodeGroup.generate!
        @node_group_c.parameters << @param_3
        @node_group_d = NodeGroup.generate!
        @node_group_d.parameters << @param_4
        @node_group_a.node_groups << @node_group_c << @node_group_d

        lambda {@node.compiled_parameters}.should_not raise_error(ParameterConflictError)
        @node.errors.on(:parameters).should be_nil
      end

      it "should include parameters of the node itself" do
        @node.parameters << Parameter.create(:key => "node_parameter", :value => "exist")

        @node.compiled_parameters.first.name.should == "node_parameter"
        @node.compiled_parameters.first.value.should == "exist"
      end

      it "should retain the history of its parameters" do
        @node_group_c = NodeGroup.generate! :name => "C"
        @node_group_d = NodeGroup.generate! :name => "D"
        @node_group_c.parameters << Parameter.generate(:key => 'foo', :value => '3')
        @node_group_d.parameters << Parameter.generate(:key => 'foo', :value => '4')
        @node_group_a.node_groups << @node_group_c
        @node_group_a.node_groups << @node_group_d

        @node.compiled_parameters.should == [
          OpenStruct.new(:name => 'foo', :value => '1', :sources => Set[@node_group_a]),
          OpenStruct.new(:name => 'bar', :value => '2', :sources => Set[@node_group_b])
        ]
      end
    end
  end

  describe "when assigning classes" do
    before :each do
      @node    = Node.generate!
      @classes = Array.new(3) { NodeClass.generate! }
    end

    it "should not remove classes if node_class_ids and node_class_names are unspecified" do
      @node.node_classes << @classes.first
      lambda {@node.update_attribute(:name, 'new_name')}.should_not change{@node.node_classes.size}
    end

    describe "via node_class_ids" do
      it "should be able to assign a single class" do
        @node.node_class_ids = @classes.first.id

        @node.should be_valid
        @node.errors.should be_empty
        @node.node_classes.size.should == 1
        @node.node_classes.should include(@classes.first)
      end

      it "should be able to assign multiple classes" do
        @node.node_class_ids = [@classes.first.id, @classes.last.id]

        @node.should be_valid
        @node.errors.should be_empty
        @node.node_classes.size.should == 2
        @node.node_classes.should include(@classes.first, @classes.last)
      end
    end

    describe "via node_class_names" do
      it "should be able to assign a single class" do
        @node.node_class_names = @classes.first.name

        @node.should be_valid
        @node.errors.should be_empty
        @node.node_classes.size.should == 1
        @node.node_classes.should include(@classes.first)
      end

      it "should be able to assign multiple classes" do
        @node.node_class_names = [@classes.first.name, @classes.last.name]

        @node.should be_valid
        @node.errors.should be_empty
        @node.node_classes.size.should == 2
        @node.node_classes.should include(@classes.first, @classes.last)
      end
    end

    describe "via node_class_ids, and node_class_names" do
      it "should assign all specified classes" do
        @node.node_class_names = @classes.first.name
        @node.node_class_ids   = @classes.last.id

        @node.should be_valid
        @node.errors.should be_empty
        @node.node_classes.size.should == 2
        @node.node_classes.should include(@classes.first, @classes.last)
      end
    end
  end

  describe "when assigning groups" do
    before :each do
      @node   = Node.generate!
      @groups = Array.new(3) { NodeGroup.generate! }
    end

    it "should not remove groups if node_group_ids and node_group_names are unspecified" do
      @node.node_groups << @groups.first
      lambda {@node.update_attribute(:name, 'new_name')}.should_not change{@node.node_groups.size}
    end

    describe "via node_group_ids" do
      it "should be able to assign a single group" do
        @node.node_group_ids = @groups.first.id

        @node.should be_valid
        @node.errors.should be_empty
        @node.node_groups.size.should == 1
        @node.node_groups.should include(@groups.first)
      end

      it "should be able to assign multiple groups" do
        @node.node_group_ids = [@groups.first.id, @groups.last.id]

        @node.should be_valid
        @node.errors.should be_empty
        @node.node_groups.size.should == 2
        @node.node_groups.should include(@groups.first, @groups.last)
      end
    end

    describe "via node_group_names" do
      it "should be able to assign a single group" do
        @node.node_group_names = @groups.first.name

        @node.should be_valid
        @node.errors.should be_empty
        @node.node_groups.size.should == 1
        @node.node_groups.should include(@groups.first)
      end

      it "should be able to assign multiple groups" do
        @node.node_group_names = [@groups.first.name, @groups.last.name]

        @node.should be_valid
        @node.errors.should be_empty
        @node.node_groups.size.should == 2
        @node.node_groups.should include(@groups.first, @groups.last)
      end
    end

    describe "via node_group_ids, and node_group_names" do
      before :each do
        @groups = Array.new(3) { NodeGroup.generate! }
      end

      it "should assign all specified groups" do
        @node.node_group_names = @groups.first.name
        @node.node_group_ids   = @groups.last.id

        @node.should be_valid
        @node.errors.should be_empty
        @node.node_groups.size.should == 2
        @node.node_groups.should include(@groups.first, @groups.last)
      end
    end
  end

  describe "destroying" do
    before :each do
      @node = Node.generate!(:name => 'gonnadienode')
    end

    it("should destroy dependent reports") do
      @report = Report.generate!(:host => @node.name)
      @node.destroy
      Report.all.should_not include(@report)
    end

    it "should remove class memberships" do
      node_class = NodeClass.generate!()
      @node.node_classes << node_class

      @node.destroy

      node_class.nodes.should be_empty
      node_class.node_class_memberships.should be_empty
    end

    it "should remove group memberships" do
      node_group = NodeGroup.generate!()
      @node.node_groups << node_group

      @node.destroy

      node_group.nodes.should be_empty
      node_group.node_group_memberships.should be_empty
    end
  end

  describe "facts" do
    before :each do
      @node = Node.generate!(:name => 'gonaddynode')
      @sample_pson = '{"name":"foo","timestamp":"Fri Oct 29 10:33:53 -0700 2010","expiration":"Fri Oct 29 11:03:53 -0700 2010","values":{"a":"1","b":"2"}}'
      SETTINGS.stubs(:inventory_server).returns('fred')
      SETTINGS.stubs(:inventory_port).returns(12345)
    end

    it "should return facts from an external REST call" do
      PuppetHttps.stubs(:get).with("https://fred:12345/production/facts/gonaddynode", 'pson').returns(
        @sample_pson)
      timestamp = Time.parse("Fri Oct 29 10:33:53 -0700 2010")
      @node.facts.should == { :timestamp => timestamp, :values => { "a" => "1", "b" => "2" }}
    end

    it "should properly CGI escape the node name in the REST call" do
      @node.name = '&/='
      PuppetHttps.expects(:get).with("https://fred:12345/production/facts/%26%2F%3D", 'pson').returns(
        @sample_pson)
      @node.facts
    end
  end
end

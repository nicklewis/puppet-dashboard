require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe NodeGroup do
  describe "associations" do
    before { @node_group = NodeGroup.spawn }
    it { should have_many(:node_classes).through(:node_group_class_memberships) }
    it { should have_many(:nodes).through(:node_group_memberships) }
  end

  describe "when destroying" do
    before :each do
      @group = NodeGroup.generate!()
    end

    it "should disassociate nodes" do
      node = Node.generate!()
      node.node_groups << @group

      @group.destroy

      node.node_groups.reload.should be_empty
      node.node_group_memberships.reload.should be_empty
    end

    it "should disassociate node_classes" do
      node_class = NodeClass.generate!()
      @group.node_classes << node_class

      @group.destroy

      node_class.node_groups.reload.should be_empty
      node_class.node_group_class_memberships.reload.should be_empty
    end

    it "should disassociate node_groups" do
      group_last = NodeGroup.generate!()
      group_first = NodeGroup.generate!()

      group_first.node_groups << @group
      @group.node_groups << group_last

      @group.destroy

      group_first.reload.node_groups.should be_empty
      group_first.node_group_edges_out.should be_empty
      NodeGroupEdge.all.should be_empty
    end
  end

  describe "when including groups" do
    before do
      @node_group_a = NodeGroup.generate! :name => "A"
      @node_group_b = NodeGroup.generate! :name => "B"
    end

    it "should not allow a group to include itself" do
      @node_group_a.node_group_names = "A"
      @node_group_a.save

      @node_group_a.should_not be_valid
      @node_group_a.errors.full_messages.should include("Validation failed: Creating a dependency from group 'A' to itself creates a cycle")
      @node_group_a.node_groups.should be_empty
    end

    it "should not allow a cycle to be formed" do
      @node_group_b.node_groups << @node_group_a
      @node_group_a.node_group_names = "B"
      @node_group_a.save

      @node_group_a.should_not be_valid
      @node_group_a.errors.full_messages.should include("Validation failed: Creating a dependency from group 'A' to group 'B' creates a cycle")
      @node_group_a.node_groups.should be_empty
    end

    it "should allow a group to be included twice" do
        @node_group_c = NodeGroup.generate!
        @node_group_d = NodeGroup.generate!
        @node_group_a.node_groups << @node_group_c
        @node_group_b.node_groups << @node_group_c
        @node_group_d.node_group_names = ["A","B"]

        @node_group_d.should be_valid
        @node_group_d.errors.should be_empty
        @node_group_d.node_groups.should include(@node_group_a,@node_group_b)
      end
  end
end

class CreateBaselines < ActiveRecord::Migration
  def self.up
    create_table :baselines do |t|
      t.integer :node_id
      t.integer :report_id
    end
  end

  def self.down
    drop_table :baselines
  end
end

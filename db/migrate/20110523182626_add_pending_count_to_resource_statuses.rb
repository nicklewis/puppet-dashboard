class AddPendingCountToResourceStatuses < ActiveRecord::Migration
  def self.up
    add_column :reports,            :pending_count,   :integer
    add_column :reports,            :compliant_count, :integer
    add_column :reports,            :failed_count,    :integer
    add_column :resource_statuses,  :pending_count,   :integer

    Report.update_all('pending_count = 0, failed_count = 0, compliant_count = 0')

    pending_reports = ResourceStatus.find(:all, :conditions => ["resource_events.status = 'noop'"], :include => [:report, :events]).group_by(&:report)
    pending_reports.each do |report, resource_statuses|
      resource_statuses.each do |res|
        res.pending_count = res.events.count { |e| e.status == 'noop' }
        res.save!
      end

      report.pending_count = resource_statuses.reject(&:failed).count
      report.save!
    end

    failed_reports = ResourceStatus.find(:all, :conditions => {:failed => true}, :include => [:report]).group_by(&:report)
    failed_reports.each do |report, resource_statuses|
      report.failed_count = resource_statuses.count
      report.compliant_count = report.resource_statuses.count - report.failed_count - report.pending_count
      report.save!
    end
  end

  def self.down
    remove_column :reports, :pending_count
    remove_column :reports, :compliant_count
    remove_column :reports, :failed_count
    remove_column :resource_statuses, :pending_count
  end
end

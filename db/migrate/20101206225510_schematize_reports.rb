require "#{RAILS_ROOT}/lib/progress_bar"

class Report < ActiveRecord::Base
  serialize :report, Puppet::Transaction::Report

  def report
    rep = read_attribute(:report)
    rep.extend(ReportExtensions) unless rep.nil? or rep.is_a? ReportExtensions
    rep
  end
end

class SchematizeReports < ActiveRecord::Migration
  def self.up
    create_table :report_logs do |t|
      t.integer :report_id, :null => false
      t.string :level
      t.string :message
      t.string :source
      t.string :tags
      t.datetime :time
      t.string :file
      t.integer :line
    end

    add_index :report_logs, [:report_id]

    create_table :resource_statuses do |t|
      t.integer :report_id, :null => false
      t.string :resource_type
      t.string :title
      t.decimal :evaluation_time, :scale => 6, :precision => 12
      t.string :file
      t.integer :line
      t.string :source_description
      t.string :tags
      t.datetime :time
      t.integer :change_count
      t.boolean :out_of_sync
    end

    add_index :resource_statuses, [:report_id]

    create_table :resource_events do |t|
      t.integer :resource_status_id, :null => false
      t.string :previous_value
      t.string :desired_value
      t.string :message
      t.string :name
      t.string :property
      t.string :source_description
      t.string :status
      t.string :tags
      t.datetime :time
    end

    add_index :resource_events, [:resource_status_id]

    create_table :metrics do |t|
      t.integer :report_id, :null => false
      t.string :category
      t.string :name
      t.decimal :value, :scale => 6, :precision => 12
    end

    add_index :metrics, [:report_id]

    change_table :reports do |t|
      t.string :kind
      t.string :puppet_version
      t.string :configuration_version
    end

    remove_column :reports, :created_at
    remove_column :reports, :updated_at

    FileUtils.mkdir_p(File.join(Rails.root, "yaml"))

    reports = Report.all
    pbar = ProgressBar.new("Migrating Reports:", reports.size, STDOUT)
    reports.each do |report|
      pbar.inc
      File.open(File.join(Rails.root, "yaml", "#{report.id}.yaml"), "w").write(report.report_before_type_cast)

      raw_report = report.report
      report.kind = raw_report.kind

      raw_report.logs.each do |log|
        if log.source == "Puppet"
          report.puppet_version ||= log.version
        else
          report.configuration_version ||= log.version
        end

        ActiveRecord::Base.connection.insert("INSERT INTO report_logs
                                              (report_id, level, message, source, tags, time, file, line)
                                              VALUES 
                                              (#{report.id}, '#{log.level}', '#{log.message and log.message.gsub("'","''")}', '#{log.source}', '#{log.tags.to_yaml.gsub("'","''")}', '#{log.time.to_s(:db)}', '#{log.file}', '#{log.line}')")
        #ReportLog.create!(
        #  :report_id => report.id,
        #  :level => log.level,
        #  :message => log.message,
        #  :source => log.source,
        #  :tags => log.tags,
        #  :time => log.time,
        #  :file => log.file,
        #  :line => log.line
        #)
      end

      raw_report.resource_statuses.each do |resource,status|
        resource =~ /^(.+?)\[(.+)\]$/
        resource_type, title = $1, $2
        resource_status_id = ActiveRecord::Base.connection.insert("INSERT INTO resource_statuses
                                                                   (report_id, resource_type, title, evaluation_time, file, line, source_description, tags, time, change_count, out_of_sync)
                                                                   VALUES
                                                                   (#{report.id}, '#{resource_type}', '#{title}', '#{status.evaluation_time}', '#{status.file}', '#{status.line}', '#{status.source_description}', '#{status.tags.to_yaml.gsub("'","''")}', '#{status.time.to_s(:db)}', '#{status.change_count}', '#{status.out_of_sync}')")
        #ResourceStatus.create!(
        #  :report_id => report.id,
        #  :resource_type => resource_type,
        #  :title => title,
        #  :evaluation_time => status.evaluation_time,
        #  :file => status.file,
        #  :line => status.line,
        #  :source_description => status.source_description,
        #  :tags => status.tags,
        #  :time => status.time,
        #  :change_count => status.change_count || 0,
        #  :out_of_sync => status.out_of_sync
        #)

        status.events.each do |event|
          ActiveRecord::Base.connection.insert("INSERT INTO resource_events
                                                (resource_status_id, previous_value, desired_value, message, name, property, source_description, status, tags, time)
                                                VALUES
                                                (#{resource_status_id}, '#{event.previous_value}', '#{event.desired_value}', '#{event.message and event.message.gsub("'","''")}', '#{event.name}', '#{event.property}', '#{event.source_description}', '#{event.status}', '#{event.tags.to_yaml.gsub("'","''")}', '#{event.time.to_s(:db)}')")

          #ResourceEvent.create!(
          #  :resource_status_id => resource_status_id,
          #  :previous_value => event.previous_value,
          #  :desired_value => event.desired_value,
          #  :message => event.message,
          #  :name => event.name,
          #  :property => event.property,
          #  :source_description => event.source_description,
          #  :status => event.status,
          #  :tags => event.tags,
          #  :time => event.time
          #)
        end
      end

      total_time = nil

      raw_report.metrics.each do |metric_category, metrics|
        metrics.values.each do |name, _, value|
          total_time = value if metric_category.to_s == "time" and name.to_s == "total"
          ActiveRecord::Base.connection.insert("INSERT INTO metrics
                                                (report_id, category, name, value)
                                                VALUES
                                                (#{report.id}, '#{metric_category}', '#{name}', '#{value}')")
          #Metric.create!(
          #  :report_id => report.id,
          #  :category => metric_category,
          #  :name => name,
          #  :value => value
          #)
        end
      end

      # We need to calculate total_time for 2.6 reports, but it's already present for 2.5
      unless total_time
        time_metrics = raw_report.metric_value(:time)
        if time_metrics
          total_time = time_metrics.values.sum(&:last) 
          ActiveRecord::Base.connection.insert("INSERT INTO metrics
                                                (report_id, category, name, value)
                                                VALUES
                                                (#{report.id}, 'time', 'total', '#{total_time}')")
        end
      end

      report.save!
    end
    pbar.finish

    remove_column :reports, :report
  end

  def self.down
  end
end

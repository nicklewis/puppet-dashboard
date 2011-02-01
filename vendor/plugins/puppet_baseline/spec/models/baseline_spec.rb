require 'spec_helper'

describe Baseline do
    describe "report_make_baseline!" do
      before do
        @report  = Report.generate(:kind => "inspect", :host => "foo")
        @report2 = Report.generate(:kind => "inspect", :host => "foo")
      end

      it "should set the given report as a baseline" do
        Baseline.report_make_baseline! @report

        @report.reload
        Baseline.report_is_baseline?(@report).should == true

        Baseline.all.map(&:report).should == [@report]
      end

      it "should only allow one baseline per node" do
        Baseline.report_is_baseline?(@report).should == false
        Baseline.report_is_baseline?(@report2).should == false

        Baseline.report_make_baseline!(@report)
        Baseline.report_is_baseline?(@report).should == true
        Baseline.report_is_baseline?(@report2).should == false

        Baseline.report_make_baseline!(@report2)
        Baseline.report_is_baseline?(@report2).should == true

        Baseline.report_is_baseline?(@report).should == false

        Baseline.all.map(&:report).should == [@report2]
      end

      it "should not make non-inspection reports baselines" do
        @apply_report = Report.generate!(:kind => "apply")
        lambda { Baseline.report_make_baseline!(@apply_report) }.should raise_error(IncorrectReportKind)

        Baseline.report_is_baseline?(@apply_report).should == false
      end
    end

end

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe BaselinesController do
  describe "#make_baseline" do
    it "should fail if the report doesn't exist" do
      lambda { get :make_baseline, :id => 1 }.should raise_error(ActiveRecord::RecordNotFound)
    end

    it "should fail if the report isn't of kind 'inspect'" do
      report = Report.generate!
      lambda { get :make_baseline, :id => report.id }.should raise_error(IncorrectReportKind)
    end

    it "should create a baseline for the report" do
      report = Report.generate!(:kind => "inspect")
      get :make_baseline, :id => report.id

      Baseline.first.report.should == report
    end

    it "should redirect to the report page" do
      report = Report.generate!(:kind => "inspect")
      get :make_baseline, :id => report.id

      response.should redirect_to(report_path(report))
    end
  end

  describe "#index" do
    it "should sanitize the parameter given" do
      hostname = %q{da\ng%erous'in_put}
      report = Report.generate!(:host => hostname, :kind => "inspect")
      Baseline.report_make_baseline! report

      get :index, :term => hostname, :limit => 20, :format => :json
      JSON.load(response.body).should == [hostname]
    end

    it "should return prefix matches before substring matches" do
      Baseline.report_make_baseline! Report.generate!(:host => "beetle"  , :kind => "inspect")
      Baseline.report_make_baseline! Report.generate!(:host => "egret"   , :kind => "inspect")
      Baseline.report_make_baseline! Report.generate!(:host => "chimera" , :kind => "inspect")
      Baseline.report_make_baseline! Report.generate!(:host => "elephant", :kind => "inspect")

      get :index, :term => 'e', :limit => 20, :format => :json
      JSON.load(response.body).should == ["egret", "elephant", "beetle", "chimera"]
    end

    it "should only return the requested number of matches" do
      Baseline.report_make_baseline! Report.generate!(:host => "egret"   , :kind => "inspect")
      Baseline.report_make_baseline! Report.generate!(:host => "chimera" , :kind => "inspect")
      Baseline.report_make_baseline! Report.generate!(:host => "elephant", :kind => "inspect")
      Baseline.report_make_baseline! Report.generate!(:host => "beetle"  , :kind => "inspect")

      get :index, :term => 'e', :limit => 3, :format => :json
      JSON.load(response.body).should == ["egret", "elephant", "beetle"]
    end

    it "should fail if the format is not json" do
      get :index, :term => 'anything', :format => :html
      response.should_not be_success
      response.code.should == "406"
    end
  end
end

class ReportsController < InheritedResources::Base
  belongs_to :node, :optional => true, :finder => :find_by_url!
  protect_from_forgery :except => [:create, :upload]

  before_filter :handle_raw_post, :only => [:create, :upload]

  def create
    if SETTINGS.disable_legacy_report_upload_url
      render :text => "Access Denied, this url has been disabled, try /reports/upload", :status => 403
    else
      upload
    end
  end

  def upload
    begin
      Report.create_from_yaml(params[:report][:report])
      render :text => "Report successfully uploaded"
    rescue => e
      error_text = "ERROR! ReportsController#upload failed:"
      Rails.logger.debug error_text
      Rails.logger.debug e.message
      render :text => "#{error_text} #{e.message}", :status => 406
    end
  end

  def diff
    @my_report = Report.find(params[:id])
    @baseline_report = Report.find(params[:baseline_id])
    @diff = @baseline_report.diff(@my_report)
  end

  def diff_summary
    diff
    @resource_statuses = {:failure => [], :pass => []}
    @diff.each do |resource, differences|
      if ! differences.empty?
        @resource_statuses[:failure] << resource
      else
        @resource_statuses[:pass] << resource
      end
    end
  end

  def make_baseline
    report = Report.find( params[:id] )
    report.baseline!
    redirect_to report
  end

  def search
    inspected_resources = ResourceStatus.inspections.order("reports.time DESC")
    if params[:file_title].present? and params[:file_content].present?
      @files = inspected_resources.by_file_title(params[:file_title]).by_file_content(params[:file_content])
    elsif params[:file_title].present?
      @files = inspected_resources.by_file_title(params[:file_title])
    elsif params[:file_content].present?
      @files = inspected_resources.by_file_content(params[:file_content])
    else
      @files = []
    end
  end

  private

  def collection
    get_collection_ivar || set_collection_ivar(
      request.format == :html ? 
        paginate_scope(end_of_association_chain) : 
        end_of_association_chain
    )
  end

  def handle_raw_post
    report = params[:report]
    params[:report] = {}
    case report
    when String
      params[:report][:report] = report
    when nil
      params[:report][:report] = request.raw_post
    when Hash
      params[:report] = report
    end
  end

end

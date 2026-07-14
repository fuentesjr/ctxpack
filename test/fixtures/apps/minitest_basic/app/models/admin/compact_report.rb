class Admin::CompactReport
  def summarize
    ReportAudit.record
  end
end

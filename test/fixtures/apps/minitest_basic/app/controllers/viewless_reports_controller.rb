class ViewlessReportsController < ApplicationController
  def preview
    head :no_content
  end
end

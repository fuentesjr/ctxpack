class OdditiesController < ApplicationController
  def merged?
    head :ok
  end

  def _show_secure_deprecated
    head :gone
  end
end

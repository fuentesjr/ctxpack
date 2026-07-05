class CallbackEdgesController < ApplicationController
  before_action :literal_callback, only: [:upgrade]
  before_action :single_symbol_callback, only: :upgrade
  before_action :symbol_skipped_callback, only: [:upgrade]
  skip_before_action :symbol_skipped_callback, only: :upgrade
  before_action :dynamic_options_callback, only: callback_actions
  before_action callback_name, only: [:upgrade]
  before_action :conditional_callback, only: [:upgrade], if: -> { true }
  before_action :skipped_callback, only: [:upgrade]
  skip_before_action :skipped_callback, only: [:upgrade]
  before_action :dynamic_skip_callback, only: [:upgrade]
  skip_before_action :dynamic_skip_callback, only: dynamic_skip_actions
  before_action :external_callback, only: [:upgrade]
  after_action :after_callback, only: [:upgrade]
  around_action :around_callback, only: [:upgrade]
  before_action(only: [:upgrade]) { touch_request_context }

  def upgrade
    head :ok
  end

  private

  def literal_callback
    @literal = true
  end

  def single_symbol_callback
    @single_symbol = true
  end

  def symbol_skipped_callback
    @symbol_skipped = true
  end

  def dynamic_options_callback
    @dynamic_options = true
  end

  def conditional_callback
    @conditional = true
  end

  def skipped_callback
    @skipped = true
  end

  def dynamic_skip_callback
    @dynamic_skip = true
  end

  def after_callback
    @after = true
  end

  def around_callback
    yield
  end
end

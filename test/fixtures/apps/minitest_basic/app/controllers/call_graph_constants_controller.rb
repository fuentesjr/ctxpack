class CallGraphConstantsController < ApplicationController
  before_action :direct_callback_constants, only: [:cap_pressure]
  before_action :shared_loader, only: [:callback_callee]

  def motivate
    load_users
    head :ok
  end

  def cap_pressure
    DirectAlpha.prepare
    DirectBeta.prepare
    load_transitive_epsilon
    head :ok
  end

  def mutual
    first_recursive
    head :ok
  end

  def callback_callee
    shared_loader
    head :ok
  end

  def ignored_calls
    self.literal_helper
    foo.receiver_helper
    SomeService.call
    send(:dynamic_helper)
    public_send(:dynamic_helper)
    head :ok
  end

  private

  def load_users
    CallGraphUser.all
  end

  def direct_callback_constants
    DirectGamma.prepare
    DirectDelta.prepare
  end

  def load_transitive_epsilon
    TransitiveEpsilon.prepare
  end

  def first_recursive
    MutualFirst.touch
    second_recursive
  end

  def second_recursive
    MutualSecond.touch
    first_recursive
  end

  def shared_loader
    SharedCallbackConstant.prepare
    deeper_shared
  end

  def deeper_shared
    SharedDeepConstant.prepare
  end

  def literal_helper
    LiteralSelfConstant.prepare
  end

  def receiver_helper
    IgnoredReceiverConstant.prepare
  end

  def dynamic_helper
    IgnoredDynamicConstant.prepare
  end
end

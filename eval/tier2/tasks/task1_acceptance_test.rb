# frozen_string_literal: true

# Tier 2 acceptance test — task 1 (feature at twofa#deactivate_init).
# Hidden from the agent; copied to test/functional/ in the scoring
# environment only. See eval/tier2/PREREGISTRATION.md.

require_relative '../test_helper'

class Tier2Task1AcceptanceTest < Redmine::ControllerTest
  tests TwofaController

  def test_deactivate_init_sends_security_notification_email
    user = User.find(2)
    user.update!(:twofa_scheme => 'totp')
    @request.session[:user_id] = user.id
    ActionMailer::Base.deliveries.clear

    post :deactivate_init, :params => {:scheme => 'totp'}

    assert_response :redirect
    mail = ActionMailer::Base.deliveries.detect { |m| m.to.include?(user.mail) }
    assert_not_nil mail,
                   "expected a security notification email to #{user.mail} " \
                   'after 2FA deactivation was initiated'
  end
end

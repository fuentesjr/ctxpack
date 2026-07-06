# frozen_string_literal: true

# Tier 2 acceptance test — task 3 (behavior change at roles#create).
# Hidden from the agent; copied to test/functional/ in the scoring
# environment only. See eval/tier2/PREREGISTRATION.md.

require_relative '../test_helper'

class Tier2Task3AcceptanceTest < Redmine::ControllerTest
  tests RolesController

  def setup
    @request.session[:user_id] = 1 # admin
  end

  def test_create_with_missing_copy_source_creates_role_and_warns
    assert_difference 'Role.count' do
      post :create, :params => {
        :role => {:name => 'Tier2 Missing Copy'},
        :copy_workflow_from => '999999'
      }
    end
    assert_not_nil flash[:warning],
                   'expected flash[:warning] when copy_workflow_from role does not exist'
  end

  def test_create_with_valid_copy_source_does_not_warn
    copy_from = Role.find(1)
    assert_difference 'Role.count' do
      post :create, :params => {
        :role => {:name => 'Tier2 Valid Copy'},
        :copy_workflow_from => copy_from.id.to_s
      }
    end
    assert_nil flash[:warning]
    new_role = Role.find_by(:name => 'Tier2 Valid Copy')
    assert_equal copy_from.workflow_rules.count, new_role.workflow_rules.count
  end

  def test_create_without_copy_param_does_not_warn
    assert_difference 'Role.count' do
      post :create, :params => {:role => {:name => 'Tier2 No Copy'}}
    end
    assert_nil flash[:warning]
  end
end

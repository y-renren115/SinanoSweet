require 'minitest/autorun'
require 'ostruct'
require_relative '../../db/seeds/accounts'

class AccountSeedsTest < Minitest::Test
  class MemoryModel
    attr_reader :records

    def initialize
      @records = {}
    end

    def find_or_create_by!(email:)
      return @records[email] if @records.key?(email)

      record = OpenStruct.new(email: email)
      yield record
      @records[email] = record
    end
  end

  def setup
    @admins = MemoryModel.new
    @customers = MemoryModel.new
    @admin_env = { 'SEED_ADMIN_EMAIL' => 'admin@example.invalid', 'SEED_ADMIN_PASSWORD' => 'test-fixture-only' }
    @demo_env = { 'SEED_DEMO_USERS' => 'true', 'SEED_CUSTOMER_PASSWORD' => 'test-fixture-only' }
  end

  def run_seeds(env = {}, environment = 'development')
    AccountSeeds.run!(environment: environment, admin_model: @admins, customer_model: @customers, env: env)
  end

  def test_no_accounts_without_explicit_configuration
    run_seeds
    assert_empty @admins.records
    assert_empty @customers.records
  end

  def test_admin_uses_supplied_configuration
    run_seeds(@admin_env)
    assert_equal 1, @admins.records.size
    assert_equal @admin_env['SEED_ADMIN_PASSWORD'], @admins.records.values.first.password
    assert_empty @customers.records
  end

  def test_partial_or_blank_admin_configuration_is_rejected_without_writes
    [{ 'SEED_ADMIN_EMAIL' => 'admin@example.invalid' },
     { 'SEED_ADMIN_PASSWORD' => 'test-fixture-only' },
     @admin_env.merge('SEED_ADMIN_EMAIL' => ' '),
     @admin_env.merge('SEED_ADMIN_PASSWORD' => '')].each do |env|
      assert_raises(ArgumentError) { run_seeds(env) }
      assert_empty @admins.records
      assert_empty @customers.records
    end
  end

  def test_demo_accounts_are_explicit_and_use_reserved_example_addresses
    run_seeds(@demo_env)
    assert_equal 20, @customers.records.size
    assert @customers.records.keys.all? { |email| email.end_with?('@example.invalid') }
    assert @customers.records.values.all? { |customer| customer.password == @demo_env['SEED_CUSTOMER_PASSWORD'] }
    assert_empty @admins.records
  end

  def test_demo_accounts_require_nonblank_password
    [nil, '', ' '].each do |password|
      assert_raises(ArgumentError) { run_seeds(@demo_env.merge('SEED_CUSTOMER_PASSWORD' => password)) }
      assert_empty @customers.records
    end
  end

  def test_demo_accounts_are_blocked_outside_development_and_test_before_admin_creation
    ['production', 'staging'].each do |environment|
      assert_raises(ArgumentError) { run_seeds(@admin_env.merge(@demo_env), environment) }
      assert_empty @admins.records
      assert_empty @customers.records
    end
    run_seeds(@demo_env, 'test')
    assert_equal 20, @customers.records.size
  end

  def test_repeated_runs_do_not_change_existing_passwords
    run_seeds(@admin_env.merge(@demo_env))
    run_seeds(@admin_env.merge(@demo_env).merge('SEED_ADMIN_PASSWORD' => 'changed-test-fixture', 'SEED_CUSTOMER_PASSWORD' => 'changed-test-fixture'))
    assert_equal 1, @admins.records.size
    assert_equal 20, @customers.records.size
    assert_equal 'test-fixture-only', @admins.records.values.first.password
    assert @customers.records.values.all? { |customer| customer.password == 'test-fixture-only' }
  end
end

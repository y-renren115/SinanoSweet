require 'minitest/autorun'
require 'ostruct'

# Evaluate the initializer in an isolated namespace without loading Rails.
class RefileConfigurationTest < Minitest::Test
  INITIALIZER = File.expand_path('../../config/initializers/refile.rb', __dir__)

  def evaluate_configuration(env)
    derived_key = 'derived-test-key'.ljust(64, '.')
    key_generator = Object.new
    calls = []
    key_generator.define_singleton_method(:generate_key) do |purpose, size|
      calls << [purpose, size]
      derived_key
    end
    app = OpenStruct.new(key_generator: key_generator)
    rails = Object.new
    rails.define_singleton_method(:application) { app }
    refile = OpenStruct.new
    context = Module.new
    context.const_set(:ENV, env)
    context.const_set(:Rails, rails)
    context.const_set(:Refile, refile)
    context.module_eval(File.read(INITIALIZER), INITIALIZER)
    [refile.secret_key, calls, derived_key]
  end

  def test_missing_override_derives_a_purpose_specific_private_key
    key, calls, derived_key = evaluate_configuration({})
    assert_equal [['refile', 64]], calls
    assert_equal derived_key.unpack('H*').first, key
  end

  def test_explicit_override_is_used_without_derivation
    fixture = 'test-only-not-a-real-key-' * 4
    key, calls = evaluate_configuration('REFILE_SECRET_KEY' => fixture)
    assert_equal fixture, key
    assert_empty calls
  end

  def test_blank_or_short_override_fails_closed
    ['', ' ', 'short-test-fixture', ' ' * 70].each do |value|
      assert_raises(ArgumentError) { evaluate_configuration('REFILE_SECRET_KEY' => value) }
    end
  end
end

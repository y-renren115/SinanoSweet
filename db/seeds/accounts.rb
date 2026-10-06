# Account creation is explicit and never changes an existing account's password.
module AccountSeeds
  def self.run!(environment:, admin_model:, customer_model:, env: ENV)
    admin_requested = env.key?('SEED_ADMIN_EMAIL') || env.key?('SEED_ADMIN_PASSWORD')
    demo_requested = env['SEED_DEMO_USERS'] == 'true'

    # Validate every requested option before creating any account.
    if admin_requested && ['SEED_ADMIN_EMAIL', 'SEED_ADMIN_PASSWORD'].any? { |key| env[key].to_s.strip.empty? }
      raise ArgumentError, 'Set both SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD, or omit both.'
    end
    if demo_requested && !['development', 'test'].include?(environment.to_s)
      raise ArgumentError, 'Demo accounts are only allowed in development or test.'
    end
    if demo_requested && env['SEED_CUSTOMER_PASSWORD'].to_s.strip.empty?
      raise ArgumentError, 'Set SEED_CUSTOMER_PASSWORD when SEED_DEMO_USERS=true.'
    end

    if admin_requested
      admin_model.find_or_create_by!(email: env.fetch('SEED_ADMIN_EMAIL')) do |admin|
        admin.password = env.fetch('SEED_ADMIN_PASSWORD')
      end
    end

    return unless demo_requested

    20.times do |n|
      customer_model.find_or_create_by!(email: "test_user#{n + 1}@example.invalid") do |customer|
        customer.last_name = 'テスト'
        customer.first_name = "ユーザー#{n + 1}"
        customer.last_name_kana = 'テスト'
        customer.first_name_kana = "ユーザー#{n + 1}"
        customer.phone_number = '00000000000'
        customer.postcode = '0000000'
        customer.address = 'テスト用住所'
        customer.password = env.fetch('SEED_CUSTOMER_PASSWORD')
      end
    end
  end
end

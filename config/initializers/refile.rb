# Use a private environment key, or derive a purpose-specific key from Rails.
# Never fall back to a shared literal key.
if ENV.key?('REFILE_SECRET_KEY')
  refile_secret_key = ENV.fetch('REFILE_SECRET_KEY')
  if refile_secret_key.strip.length < 64
    raise ArgumentError, 'REFILE_SECRET_KEY must contain at least 64 random characters.'
  end
  Refile.secret_key = refile_secret_key
else
  Refile.secret_key = Rails.application.key_generator.generate_key('refile', 64).unpack('H*').first
end

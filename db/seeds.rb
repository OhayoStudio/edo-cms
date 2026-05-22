# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Singleton settings — one row drives site-wide branding, theme, nav, etc.
Setting.instance

# Admin user — single account for site owner.
# Set ADMIN_EMAIL and ADMIN_PASSWORD before db:seed to override the defaults.
if User.count.zero?
  email    = ENV.fetch("ADMIN_EMAIL",    "admin@example.com")
  password = ENV.fetch("ADMIN_PASSWORD", SecureRandom.hex(16))
  User.create!(email_address: email, password: password, password_confirmation: password)
  puts "Admin user created: #{email}"
  puts "Password: #{password}" if ENV["ADMIN_PASSWORD"].blank?
end

# Optional demo content — set SEED_DEMO_CONTENT=1 to plant a handful of
# articles, videos, an author, and a category so a fresh install has
# something visible on the homepage. Production should leave this off.
load Rails.root.join("db/seeds/demo.rb") if ENV["SEED_DEMO_CONTENT"].present?

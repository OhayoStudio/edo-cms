# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Admin user — single account for site owner
# Set ADMIN_EMAIL and ADMIN_PASSWORD env vars before running db:seed
if User.count.zero?
  email    = ENV.fetch("ADMIN_EMAIL",    "jerome@ohayostudio.com")
  password = ENV.fetch("ADMIN_PASSWORD", SecureRandom.hex(16))
  User.create!(email_address: email, password: password, password_confirmation: password)
  puts "Admin user created: #{email}"
  puts "Password: #{password}" if ENV["ADMIN_PASSWORD"].blank?
end

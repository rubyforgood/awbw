admin_password = Devise::Encryptor.digest(Admin, 'password')
Admin.update_all(encrypted_password: admin_password)

user_password = Devise::Encryptor.digest(User, 'password')
User.in_batches do |batch|
  batch.update_all(encrypted_password: user_password)
end

Admin.create!(first_name: "Amy", last_name: "Admin", email: "amy.admin@example.com", password: "password")
User.create!(first_name: "Umberto", last_name: "User", email: "umberto.user@example.com", password: "password")

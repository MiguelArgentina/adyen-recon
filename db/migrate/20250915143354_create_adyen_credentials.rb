class CreateAdyenCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :adyen_credentials do |t|
      t.string :label
      t.string :sftp_host
      t.string :sftp_username
      t.integer :sftp_port
      t.integer :auth_method
      t.text :encrypted_private_key
      t.text :encrypted_passphrase

      t.timestamps
    end
  end
end

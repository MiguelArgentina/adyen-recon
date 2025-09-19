class AdyenCredential < ApplicationRecord
  enum :auth_method, { ssh_key: 0, password: 1 }, prefix: :auth
end

class User

  has_secure_password

  validates :password, length: { minimum: 8, allow_blank: true }

  when_attribute :password_digest, changes_to: :anything do
    before_save do
      self.password_reset_token = nil
      self.password_reset_token_valid_until = nil
    end
  end

  def self.authenticate(email_address, password)
    user = where(email_address: email_address).first
    raise Postal::Errors::AuthenticationError.new("InvalidEmailAddress") if user.nil?
    raise Postal::Errors::AuthenticationError.new("InvalidPassword") unless user.authenticate(password)

    user
  end

  def authenticate_with_previous_password_first(unencrypted_password)
    if password_digest_changed?
      BCrypt::Password.new(password_digest_was).is_password?(unencrypted_password) && self
    else
      authenticate(unencrypted_password)
    end
  end

  def begin_password_reset(return_to = nil)
    self.password_reset_token = Nifty::Utils::RandomString.generate(length: 24)
    self.password_reset_token_valid_until = 1.day.from_now
    save!
    AppMailer.password_reset(self, return_to).deliver
  end

end

class Postal::Errors::AuthenticationError < Postal::Error

  attr_reader :error

  def initialize(error)
    @error = error
  end

  def to_s
    "Authentication Failed: #{@error}"
  end

end

# -*- SkipSchemaAnnotations

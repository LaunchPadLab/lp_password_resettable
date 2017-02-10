module LpResettable
  class Config

    # Number of days the password reset token is active - default 1
    attr_accessor :reset_token_lifetime

    # Number of characters of the password reset token - default 20
    attr_accessor :reset_token_length

    def initialize
      @reset_token_lifetime = 1
      @reset_token_length = 20
    end
  end
end

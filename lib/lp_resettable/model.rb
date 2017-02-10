require 'lp_resettable/error'
require 'securerandom'

module LpResettable
  class Model
    class << self
      def check_resettable!(klass, email)
        check_reset_columns!(klass)
        check_email!(klass, email)
      end

      def check_reset_columns!(klass)
        raise Error, "#{klass} not resettable" unless reset_columns?(klass)
      end

      def reset_columns?(klass)
        return false unless klass.respond_to? :column_names

        column_names = klass.column_names

        %w(
          reset_token
          reset_sent_at
        ).all? { |attr| column_names.include? attr }
      end

      def check_email!(klass, email)
        raise Error, "That email doesn't match any records" unless email_exists?(klass, email)
      end

      def email_exists?(klass, email)
        klass.find_by(email: email)
      end

      def set_reset_token!(model, token_length=LpResettable.config.reset_token_length)
        check_reset_columns!(model.class)

        reset_token = generate_reset_token(token_length)
        model.update_columns(
          reset_token: reset_token,
          reset_sent_at: nil
        )
        reset_token
      end

      def generate_reset_token(length)
        rlength = (length * 3) / 4
        SecureRandom.urlsafe_base64(rlength).tr('lIO0', 'sxyz')
      end

      def send_reset_instructions!(model)
        check_reset_columns!(model.class)
        check_reset_not_sent!(model)

        yield if block_given?

        model.update_columns(reset_sent_at: Time.now)
      end

      def check_reset_not_sent!(model)
        raise Error, 'reset already sent' unless reset_not_sent?(model)
      end

      def reset_not_sent?(model)
        model.reset_sent_at == nil
      end

      def reset_by_token!(klass, reset_token, new_password, new_password_confirmation)
        check_reset_columns!(klass)
        model = klass.find_by(reset_token: reset_token)
        check_token!(model)

        model.update(reset_token: nil,
                    password: new_password,
                    password_confirmation: new_password_confirmation
                    )
        model
      end

      def check_token!(model)
        raise Error, 'reset token expired' unless token_active?(model)
      end

      def token_active?(model)
        model.reset_token &&
        model.reset_sent_at &&
        Time.now <= (model.reset_sent_at + (LpResettable.config.reset_token_lifetime * 60 * 60 * 24))
      end
    end
  end
end

require 'minitest/autorun'
require 'lp_resettable'

def days(duration=1)
  duration * 60 * 60 * 24
end

VALID_EMAIL = 'valid_email@example.com'
INVALID_EMAIL = 'invalid_email@example.com'


RESET_COLS = %w(
  reset_token
  reset_sent_at
)

class MockActiveRecord
  def self.column_names
    ['email']
  end

  def self.find_by(**kwargs)
    MockActiveRecord.new
  end

  def update_columns(**kwargs)
    kwargs.each { |k, v| send("#{k}=", v) }
  end

  def update(**kwargs)
    kwargs.each { |k, v| send("#{k}=", v) }
  end
end

class MockResettable < MockActiveRecord
  attr_accessor *RESET_COLS, :email, :password, :password_confirmation

  def self.column_names
    super
    RESET_COLS
  end

  def self.find_by(**kwargs)
    resettable = MockResettable.new

    if kwargs.has_key?(:reset_token)
      resettable.reset_token = kwargs[:reset_token]

      if kwargs[:reset_token] == 'expired'
        resettable.reset_sent_at = Time.now - 1000 * days
      end

      if kwargs[:reset_token] == 'active'
        resettable.reset_sent_at = Time.now - 1 * days
      end
    end

    if kwargs.has_key?(:email)
      return nil unless kwargs[:email] === VALID_EMAIL
    end
    resettable
  end
end

describe LpResettable::Config do
  it 'has defaults' do
    assert LpResettable.config.reset_token_lifetime
    assert LpResettable.config.reset_token_length
  end

  it 'can be configured' do
    default_token_lifetime = LpResettable.config.reset_token_lifetime
    new_token_lifetime = default_token_lifetime + 5
    LpResettable.config do |config|
      config.reset_token_lifetime = new_token_lifetime
    end
    assert_equal LpResettable.config.reset_token_lifetime, new_token_lifetime
  end
end

LPR = LpResettable::Model

describe LpResettable::Model do

  before do
    LpResettable.config do |config|
      config.reset_token_lifetime = 2
      config.reset_token_length = 20
    end
  end

  describe '#reset_columns?' do

    it 'anything' do
      refute LPR.reset_columns? String
    end

    it 'active record without migration' do
      refute LPR.reset_columns? MockActiveRecord
    end

    it 'reset_columns' do
      assert LPR.reset_columns? MockResettable
    end
  end

  describe '#email_exists?' do

      it 'email exists' do
        assert LPR.email_exists?(MockResettable, VALID_EMAIL)
      end

      it 'email does not exist' do
        refute LPR.email_exists?(MockResettable, INVALID_EMAIL)
      end
  end

  describe '#check_reset_columns!' do

    it 'anything' do
      assert_raises LpResettable::Error do
        LPR.check_reset_columns! String
      end
    end

    it 'active record' do
      assert_raises LpResettable::Error do
        LPR.check_reset_columns! MockActiveRecord
      end
    end

    it 'reset_columns' do
      assert_nil LPR.check_reset_columns!(MockResettable)
    end
  end

  describe '#check_email!' do

    it 'email exists' do
      assert_nil LPR.check_email!(MockResettable, VALID_EMAIL)
    end

    it 'email does not exist' do
      assert_raises LpResettable::Error do
        LPR.check_email!(MockResettable, INVALID_EMAIL)
      end
    end
  end

  describe '#check_resettable!' do

    it 'anything' do
      assert_raises LpResettable::Error do
        LPR.check_resettable!(String, VALID_EMAIL)
      end
    end

    it 'active record' do
      assert_raises LpResettable::Error do
        LPR.check_resettable!(MockActiveRecord, VALID_EMAIL)
      end
    end

    it 'no email' do
      assert_raises LpResettable::Error do
        LPR.check_resettable!(MockResettable, INVALID_EMAIL)
      end
    end

    it 'resettable' do
      assert_nil LPR.check_resettable!(MockResettable, VALID_EMAIL)
    end
  end

  describe '#set_reset_token!' do

    describe 'when not resettable' do
      before do
        @model = MockActiveRecord.new
      end

      it 'raises' do
        assert_raises LpResettable::Error do
          LPR.set_reset_token!(@model)
        end
      end
    end

    describe 'when resettable' do
      before do
        @resettable = MockResettable.new
      end

      it 'sets the reset_token to the generated reset_token' do
        reset_token = LPR.set_reset_token! @resettable
        assert_equal @resettable.reset_token, reset_token
      end

      it 'sets the reset token to the configured length' do
        LPR.set_reset_token! @resettable
        assert_equal @resettable.reset_token.length, LpResettable.config.reset_token_length
      end

      it 'sets reset sent at time to nil' do
        LPR.set_reset_token! @resettable
        assert_nil @resettable.reset_sent_at
      end

      it 'returns the reset token' do
        token = LPR.set_reset_token! @resettable
        assert_equal token, @resettable.reset_token
      end

      describe 'when token length is provided' do
        it 'sets the reset token to the provided length' do
          LPR.set_reset_token! @resettable, 40
          assert_equal @resettable.reset_token.length, 40
        end
      end
    end
  end

  describe '#reset_not_sent?' do
    before do
      @resettable = MockResettable.new
    end

    it 'when not sent' do
      assert LPR.reset_not_sent?(@resettable)
    end

    it 'when sent' do
      @resettable.reset_sent_at = Time.now - (2 * days)
      refute LPR.reset_not_sent?(@resettable)
    end
  end

  describe '#check_resent_not_sent!' do
    before do
      @resettable = MockResettable.new
    end

    it 'when not sent' do
      assert_nil LPR.check_reset_not_sent!(@resettable)
    end

    it 'when sent' do
      @resettable.reset_sent_at = Time.now - (7 * days)
      assert_raises LpResettable::Error do
        LPR.check_reset_not_sent!(@resettable)
      end
    end
  end

  describe '#send_reset_instructions!' do

    describe 'when not resettable' do
      before do
        @model = MockActiveRecord.new
      end

      it 'raises' do
        assert_raises LpResettable::Error do
          LPR.send_reset_instructions!(@model)
        end
      end
    end

    describe 'when reset sent' do
      before do
        @resettable = MockResettable.new
        @resettable.reset_token = 'foo'
        @resettable.reset_sent_at = Time.now
      end

      it 'raises' do
        assert_raises LpResettable::Error do
          LPR.send_reset_instructions!(@resettable)
        end
      end
    end

    describe 'when reset not sent' do
      before do
        @resettable = MockResettable.new
        @resettable.reset_token = 'foo'
      end

      it 'sets reset sent at' do
        LPR.send_reset_instructions!(@resettable)
        assert_in_delta @resettable.reset_sent_at, Time.now, 1
      end

      it 'calls the block if given' do
        @mock_block = Minitest::Mock.new
        @mock_block.expect(:foo, 'bar')
        LPR.send_reset_instructions! @resettable do
          @mock_block.foo
        end
        @mock_block.verify
      end
    end
  end

  describe '#token_active?' do
    before do
      @resettable = MockResettable.new
    end

    it 'when token does not exist' do
      refute LPR.token_active?(@resettable)
    end

    it 'when token sent at does not exist' do
      @resettable.reset_token = 'foo'
      refute LPR.token_active?(@resettable)
    end

    it 'when token expired' do
      LpResettable.config { |config| config.reset_token_lifetime = 2 }
      @resettable.reset_token = 'foo'
      @resettable.reset_sent_at = Time.now - (5 * days)
      refute LPR.token_active?(@resettable)
    end

    it 'when token active' do
      LpResettable.config { |config| config.reset_token_lifetime = 2 }
      @resettable.reset_token = 'foo'
      @resettable.reset_sent_at = Time.now - (1 * days)
      assert LPR.token_active?(@resettable)
    end
  end

  describe '#check_token!' do
    before do
      @resettable = MockResettable.new
    end

    it 'when token not active' do
      assert_raises LpResettable::Error do
        LPR.check_token!(@resettable)
      end
    end

    it 'when token active' do
      LpResettable.config { |config| config.reset_token_lifetime = 2 }
      @resettable.reset_token = 'foo'
      @resettable.reset_sent_at = Time.now - (1 * days)
      assert_nil LPR.check_token!(@resettable)
    end
  end

  describe '#reset_by_token!' do
    before do
      @new_password = 'new_password'
      @new_password_confirmation = 'new_password'
    end

    describe 'when not resettable' do
      before do
        @klass = MockActiveRecord
        @token = 'foo'

      end

      it 'raises' do
        assert_raises LpResettable::Error do
          LPR.reset_by_token!(@klass, @token, @new_password, @new_password_confirmation)
        end
      end
    end

    describe 'when expired' do
      before do
        @klass = MockResettable
        @token = 'expired'
      end

      it 'raises' do
        assert_raises LpResettable::Error do
          LPR.reset_by_token!(@klass, @token, @new_password, @new_password_confirmation)
        end
      end
    end

    describe 'when active' do
      before do
        @klass = MockResettable
        @token = 'active'
      end

      it 'sets the password to new_password' do
        model = LPR.reset_by_token!(@klass, @token, @new_password, @new_password_confirmation)
        assert_equal model.password, @new_password
      end

      it 'sets the password_confirmation to new_password_confirmation' do
        model = LPR.reset_by_token!(@klass, @token, @new_password, @new_password_confirmation)
        assert_equal model.password_confirmation, @new_password_confirmation
      end

      it 'sets the reset token to nil' do
        model = LPR.reset_by_token!(@klass, @token, @new_password, @new_password_confirmation)
        assert_nil model.reset_token
      end

      it 'returns the model' do
        model = LPR.reset_by_token!(@klass, @token, @new_password, @new_password_confirmation)
        assert_instance_of MockResettable, model
      end
    end
  end
end

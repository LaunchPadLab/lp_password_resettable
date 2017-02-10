# LP Resettable
Simple password reset logic for Rails apps. No baked in routing or mailers, just the barebones logic and migration you need to implement resettable logic for your users.

## Installation
Add `gem lp_resettable,  github: 'launchpadlab/lp_resettable'` to your Gemfile and run `bundle install`.

## Usage
For the purposes of these instructions, I will assume the model you are using is 'User' but it could be anything you want. I will also assume your User model has an 'email' field and virtual attributes for 'password' and 'password_confirmation'

1. Generate a migration to add the required fields to the model of your choice with `bundle exec rails generate lp_resettable:model User`
2. Run the migration with `bundle exec rails db:migrate`. This adds three columns to your table: `reset_token`, and `reset_sent_at`.
3. When you want to start the process, assume you have created a `user`, then call `LpResettable::Model.set_reset_token! user`. This will return the token that you can share with the client via email, link, smoke-signals, whatever.
4. While you are in charge of sending reset instructions, `lp_resettable` still needs to track it, so when you are ready call
```
LpResettable::Model.send_send_instructions! user do
    <insert your logic here>
end
```
and 'lp_resettable' will take care of the rest.

5. To reset a user's password, call `LpResettable::Model.reset_by_token!(User, reset_token, new_password, new_password_confirmation)`. This will find the user by reset token, update their password and passwword_confirmation fields, and return the user model.
6. Any errors that pop up along the way, such as trying to reset a non-resettable object, or an expired token, etc..., will throw an `LpResettable::Error`.
7. To change the global defaults run `bundle exec rails generate lp_resettable:install` to generate an initializer at `../config/initalizers/lp_resettable.rb`. See the initializer for more details.

## Development
+ `git clone git@github.com:LaunchPadLab/lp_resettable.git`
+ `bundle install`
+ Test with `rake`

## Reset those passwords!

Given /^I am not authenticated$/ do
  page.driver.submit :delete, "/admins/sign_out", {}
end

Given /^I am a new, authenticated user$/ do
  email = 'testing@man.net'
  password = 'secretpass'
  Admin.new(:email => email, :password => password, :password_confirmation => password).save!

  visit '/admins/sign_in'
  fill_in "admin_email", :with => email
  fill_in "admin_password", :with => password
  click_button "Sign in"

end

Then(/^I should see the login page$/) do
	page.should have_content("You need to sign in or sign up before continuing")
end

# features/step_definitions/home_page_steps.rb
Given(/^there's a client named "(.*?)" with "(.*?)" domain$/) do |name, domain|
  @post = FactoryGirl.create(:client, name: name, domain_name: domain, status: 'active')
end

When(/^I am on the clients page$/) do
  visit clients_path
end

Then(/^I should see the "(.*?)" record$/) do |name|
  @client = Client.where(name: name).first

  page.should have_content(@client.name)
  page.should have_content(@client.domain_name)
end
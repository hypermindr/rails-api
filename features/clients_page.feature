# features/home_page.feature
Feature: Clients page

  Scenario: Viewing application's clients page (authenticated)
    Given there's a client named "My client" with "google.com" domain
    Given I am a new, authenticated user
    When I am on the clients page
    Then I should see the "My client" record

  Scenario: Viewing application's clients page (not authenticated)
    Given there's a client named "My client" with "google.com" domain
    Given I am not authenticated
    When I am on the clients page
    Then I should see the login page
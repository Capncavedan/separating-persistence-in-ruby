Feature: As a user, I want to submit shipments for tracking and review information about them

  Background:
    Given I have a user account

  Scenario: enter a tracking number manually
    When I log in
    And I click "+ enter new"
    And I fill out the form with my UPS shipment information
    Then I should be on the shipments list page
    And I should see my UPS shipment information

  Scenario: forward an email with tracking information
    When I forward an email with my FedEx shipment information
    And I log in
    Then I should be on the shipments list page
    And I should see my FedEx shipment information

  Scenario: shipment gets delivered, I receive an email
    Given I have a USPS shipment tracked on the site
    When that shipment gets delivered
    Then I should receive an email telling me it was delivered

require 'test_helper'

class DonationsControllerTest < ActionDispatch::IntegrationTest
  test "we can create a donation" do
    post donations_create_url, params: {donation: {category: DonationCategory::PRODUCE, food_name: 'bananas!!!',
                                                   total_amount:'20 bunches', donor_id: 1, pickup_instructions: 'Front door',
                                                   status: DonationStatus::ACTIVE}}, headers: auth_header({donor_id: 1})
    assert_response :success
    assert_not_nil Donation.find_by_food_name 'bananas!!!'
  end

  test "failed validation causes 422 response" do
    food_name = 'carrots!!!'
    post donations_create_url, params: {donation: { food_name: food_name,
                                                   total_amount:'20 bunches', donor_id: 1, pickup_instructions: 'Front door',
                                                   status: DonationStatus::ACTIVE}}, headers: auth_header({donor_id: 1})
    assert_response 422
    res_obj = JSON.parse @response.body
    assert_equal "Category can't be blank", res_obj['errors'][0], 'should have complained about missing category'
    assert_nil Donation.find_by_food_name food_name
  end

  test "authentication is required" do
    post donations_create_url, params: {donation: {}}
    assert_response :unauthorized
  end

  test "active donations returns 1 record and marks another expired" do
    active_donations = Donation.where status: DonationStatus::ACTIVE
    assert_equal 2, active_donations.size, 'Should have found two donations with status=active, check donations.yml'
    get '/donations/active', headers: auth_header({donor_id: 1})
    assert_response :success
    active_donations_api = JSON.parse @response.body
    assert_equal 1, active_donations_api.size, 'should have returned one active donation'
    assert_equal 'not expired food', active_donations_api[0]['food_name'], 'returned unexpected active donation, check donations.yml'
    active_donations = Donation.where status: DonationStatus::ACTIVE
    assert_equal 1, active_donations.size, 'Accessing the active donations through the api should have marked one expired'
  end

  test "update donation status succeeds" do
    patch '/donations/2/update', params: {donation: {id:2, status:DonationStatus::DELETED}}, headers: auth_header({donor_id: 1})
    assert_response :success
    donation_in_db = Donation.find_by_id(2)
    assert_equal DonationStatus::DELETED, donation_in_db.status, 'should have changed status to deleted'
  end

  test "only updates to donations owned by logged in donor" do
    patch '/donations/2/update', params: {donation: {id:2, status:DonationStatus::DELETED}}, headers: auth_header({donor_id: 2})
    assert_response :unauthorized
  end

end

require 'katello_test_helper'

class Actions::Candlepin::Product::ContentUpdateTest < ActiveSupport::TestCase
  include Dynflow::Testing
  include Support::Actions::RemoteAction

  before do
    stub_remote_user
  end

  describe 'Create' do
    let(:action_class) { ::Actions::Candlepin::Product::Create }
    let(:planned_action) do
      create_and_plan_action action_class, :name => 'foo', :owner => 'default_org', :multiplier => nil, :attributes => {}
    end

    it 'runs' do
      SecureRandom.expects(:random_number).returns(4) #chosen by fair dice roll. guarenteed to be random.
      ::Katello::Resources::Candlepin::Product.expects(:create).with('default_org', :name => 'foo', :id => 4,
                                                                     :multiplier => nil, :attributes => {})
      run_action planned_action
    end

    it 'properly determines an unused id' do
      katello_products(:fedora).update_attributes!(:cp_id => 4)
      SecureRandom.stubs(:random_number).returns(4).then.returns(99)

      assert_equal 99, create_action(action_class).unused_product_id
    end
  end

  describe 'ContentUpdate' do
    let(:action_class) { ::Actions::Candlepin::Product::ContentUpdate }
    let(:planned_action) do
      create_and_plan_action action_class, id: 123
    end

    it 'runs' do
      ::Katello::Resources::Candlepin::Content.expects(:update)
      run_action planned_action
    end
  end
end

class Actions::Candlepin::Product::DestroyTest < ActiveSupport::TestCase
  include Dynflow::Testing
  include Support::Actions::RemoteAction

  before do
    stub_remote_user
  end

  describe "Delete Pools" do
    let(:action_class) { ::Actions::Candlepin::Product::DeletePools }
    let(:label) { "foo" }
    let(:cp_id) { "foo_boo" }
    let(:pool_id) { "100" }
    let(:pools) { [{"id" => pool_id, "cp_id" => pool_id}] }

    let(:planned_action) do
      create_and_plan_action(action_class,
                             organization_label: label,
                             cp_id: cp_id)
    end

    it 'runs' do
      ::Katello::Resources::Candlepin::Pool.expects(:destroy).with(pool_id)
      ::Katello::Resources::Candlepin::Product.expects(:pools).with(label, cp_id).returns(pools)
      run_action planned_action
    end
  end

  describe "Delete Subscriptions" do
    let(:action_class) { ::Actions::Candlepin::Product::DeleteSubscriptions }
    let(:label) { "foo" }
    let(:cp_id) { "foo_boo" }
    let(:planned_action) do
      create_and_plan_action(action_class,
                             organization_label: label,
                             cp_id: cp_id)
    end

    it 'runs' do
      ::Katello::Resources::Candlepin::Product.expects(:delete_subscriptions).with(label, cp_id)
      run_action planned_action
    end
  end

  describe "Delete Unused" do
    before(:all) { stub_remote_user }
    let(:action_class) { ::Actions::Candlepin::Product::DeleteUnused }
    let(:org) { get_organization }
    let(:destroy_action) { ::Actions::Candlepin::Product::Destroy }

    context('without duplicate') do
      let(:planned_action) do
        create_and_plan_action(action_class, org)
      end

      it 'plans deletion of all products' do
        org.products.each do |product|
          assert_action_planed_with(planned_action, destroy_action, cp_id: product.cp_id)
        end
      end
    end

    context('with duplicate') do
      let(:other_org) { taxonomies(:organization1) }
      let(:redhat_product) { katello_products(:redhat) }

      let(:other_product) do
        create(:katello_product,
               :cp_id => redhat_product.cp_id,
               :organization => other_org,
               :name => redhat_product.name,
               :label => 'dont_label_me',
               :provider => other_org.redhat_provider)
      end

      let(:planned_action) do
        create_and_plan_action(action_class, other_org)
      end

      it 'does not plan deletion of duplicated product' do
        refute_action_planed(planned_action, destroy_action)
      end
    end
  end

  describe "Destroy" do
    let(:action_class) { ::Actions::Candlepin::Product::Destroy }
    let(:cp_id) { "foo_boo" }
    let(:planned_action) do
      create_and_plan_action(action_class,
                             cp_id: cp_id,
                             owner: 'whoops')
    end

    it 'runs' do
      ::Katello::Resources::Candlepin::Product.expects(:destroy).with('whoops', cp_id)
      run_action planned_action
    end
  end
end

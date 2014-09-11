require "spec_helper"

#
# We create the controller we'll be using in our tests
#
RESTFUL_ACTIONS = [:index, :show, :new, :create, :update, :edit, :destroy]

class PostsController < TestController
  # Some actions
  RESTFUL_ACTIONS.each do |action|
    define_method action do
    end
  end

  def custom(); end

  def current_user(); end
end

# We're testing BoltedController module through this one
describe PostsController, :type => :controller do
  
  before(:all) do
    PostsController.send :include, StrongBolt::BoltedController
    define_model "Post"
    @user = User.create!
  end

  let(:user) { @user }





  #
  # Setup a current user
  #
  def setup_session
    allow_any_instance_of(PostsController).to receive(:current_user).and_return @user
  end

  #
  # Performs the right query given the action
  #
  def perform action
    case action
    when :index, :new then get action
    when :show, :edit then get action, id: 1
    when :update then put :update, id: 1
    when :create then post :create
    when :destroy then delete :destroy, id: 1
    end
  end








  #
  # Before Filter, set current user
  #
  describe 'before_action' do

    before do
      PostsController.skip_after_action :unset_current_user
      PostsController.skip_before_action :check_authorization
    end
    after do
      PostsController.after_action :unset_current_user
      PostsController.before_action :check_authorization
    end
    
    context 'when no user' do
      before do
        expect_any_instance_of(PostsController).to receive(:current_user)
          .at_least(1).times.and_return nil
        get :index
      end
    
      it "should set nil user" do
        expect(StrongBolt.current_user).to be_nil
      end

      it "should have set $request" do
        expect($request).to be_present
      end
    end

    context "when user" do
      let(:user) { User.new }

      before do
        expect_any_instance_of(PostsController).to receive(:current_user).and_return user
        get :index
      end
    
      it "should set the user" do
        expect(StrongBolt.current_user).to eq user
      end
    end

  end

  #
  # After filter, unset current user
  #
  describe 'after_action' do

    before do
      PostsController.skip_before_action :check_authorization
    end
    after do
      PostsController.before_action :check_authorization
    end
    
    context "when a user is set" do

      before do
        expect_any_instance_of(PostsController).to receive(:current_user)
          .and_return @user
        get :index
      end
    
      it "should have unsetted the user" do
        expect(StrongBolt.current_user).to be_nil
      end
    end

  end

  #
  # Catching Grant::Error and sending StrongBolt
  #
  describe 'catching Grant::Error' do
    before do
      expect_any_instance_of(PostsController).to receive(:index)
        .and_raise Grant::Error.new "Error"
    end

    it "should raise StrongBolt::Error" do
      expect do
        get :index
      end.to raise_error StrongBolt::Unauthorized
    end
  end








  #
  # Checking authorization on a high level
  #
  describe "checking authorization" do

    #
    # When no authorization unrelated errors
    #

    context "when no error" do
    
      before(:all) do
        # Model linked to the controller
        define_model "Post" do
          self.table_name = "models"
        end
      end

      before do
        # user is the current user of our app
        allow_any_instance_of(PostsController).to receive(:current_user)
          .and_return user
      end


      #
      # Call the right CRUD operation
      #
      describe "calling the CRUD operations" do
        {
          :index    => :find,
          :show     => :find,
          :edit     => :update,
          :update   => :update,
          :new      => :create,
          :create   => :create
        }.each do |action, operation|
          context "when calling #{action}" do
            it "should call the operation" do
              expect(user).to receive(:can?).with(operation, Post).and_return true
              perform action
            end
          end
        end # End checking calling right can
      end


      #
      # When calling a custom action without CRUD associated
      #
      context "when calling unmapped action" do
        
        it "should raise ActionNotConfigured" do
          expect do
            get :custom
          end.to raise_error StrongBolt::ActionNotConfigured
        end

      end


      #
      # When not authorized
      #
      context "when not authorized" do
        before do
          expect(StrongBolt).to receive(:access_denied)
          expect(user).to receive(:can?).and_return false
        end

        it "should raise StrongBolt::Unauthorized" do
          expect do
            get :index
          end.to raise_error StrongBolt::Unauthorized
        end
      end

      #
      # When authorized
      #
      context "when authorized" do
        before do
          expect(user).to receive(:can?).and_return true
        end

        it "should not raise error" do
          expect do
            get :index
          end.not_to raise_error
        end
      end

    end # End when no error

    #
    # When the controller doesn't have any model associated
    #

    context "when controller doesn't have model" do
      
      before do
        undefine_model "Post"
        setup_session
      end

      it "should not raise error" do
        expect do
          get :index
        end.not_to raise_error
      end

    end # End when no model associated

    #
    # When no current user
    #
    context "when no current user" do
      before do
        expect(StrongBolt).to receive(:current_user).and_return nil
        expect(StrongBolt).to receive(:logger).and_call_original
      end

      it "should not raise error" do
        get :index
      end
    end

  end # End describe authorizations







  #
  # Setting a specific model for a controller
  #
  describe 'setting specific model' do

    before do
      define_model "Custom" do
        self.table_name = "models"
      end
    end
    after { PostsController.model_for_authorization = nil }
    
    context "when given as a string" do
      
      context "and not exists" do
        it "should raise error" do
          expect do
            PostsController.model_for_authorization = "FEge"
          end.to raise_error StrongBolt::ModelNotFound
        end
      end

      context 'when exists' do
        before { PostsController.model_for_authorization = "Custom" }

        it "should set it" do
          expect(PostsController.model_for_authorization).to eq Custom
        end
      end

    end # End when given as a string

    context "when given as a model" do
      before { PostsController.model_for_authorization = Custom }

      it "should set it" do
        expect(PostsController.model_for_authorization).to eq Custom
      end
    end

  end





  #
  # Fetching authorization model when not specified
  #
  describe "model_for_authorization" do
    
    context "when model is infered from controller" do
      before do
        define_model "Post"
        get :index
      end

      it "should return the model" do
        expect(PostsController.model_for_authorization).to eq Post
      end
    end

    context "when model cannot be infered" do
      before do
        undefine_model "Post"
      end

      it "should raise ModelNotFound" do
        expect do
          PostsController.model_for_authorization
        end.to raise_error StrongBolt::ModelNotFound
      end
    end

  end








  #
  # Skipping controller authorization
  #
  describe 'skip_controller_authorization' do
    
    after { PostsController.before_action :check_authorization }
    
    context "when no argument" do

      before { PostsController.skip_controller_authorization }
      
      RESTFUL_ACTIONS.each do |action|
        it "should not call check_authorization" do
          expect_any_instance_of(PostsController).not_to receive(:check_authorization)
          perform action
        end
      end

    end

    context 'with only argument' do

      before { PostsController.skip_controller_authorization only: skipped_actions }
      
      context "when 1 action" do
        
        let(:skipped_actions) { :index }

        RESTFUL_ACTIONS.each do |action|
          it "should skip the right one - #{action}" do
            if action == skipped_actions
              expect_any_instance_of(PostsController).not_to receive(:check_authorization)
            else
              expect_any_instance_of(PostsController).to receive(:check_authorization)
            end
            perform action
          end
        end

      end # End 1 action

      context "when several actions" do
        
        let(:skipped_actions) { [:show, :index] }

        RESTFUL_ACTIONS.each do |action|
          it "should skip the right ones - #{action}" do
            if skipped_actions.include? action
              expect_any_instance_of(PostsController).not_to receive(:check_authorization)
            else
              expect_any_instance_of(PostsController).to receive(:check_authorization)
            end
            perform action
          end
        end

      end # End several actions

    end # End when only argument

    context "with except argument" do
      
      before { PostsController.skip_controller_authorization except: preserved_actions }
      
      context "when 1 action" do
        
        let(:preserved_actions) { :index }

        RESTFUL_ACTIONS.each do |action|
          it "should preserve the right one - #{action}" do
            if action == preserved_actions
              expect_any_instance_of(PostsController).to receive(:check_authorization)
            else
              expect_any_instance_of(PostsController).not_to receive(:check_authorization)
            end
            perform action
          end
        end

      end # End 1 action

      context "when several actions" do
        
        let(:preserved_actions) { [:show, :index] }

        RESTFUL_ACTIONS.each do |action|
          it "should preserve the right ones - #{action}" do
            if preserved_actions.include? action
              expect_any_instance_of(PostsController).to receive(:check_authorization)
            else
              expect_any_instance_of(PostsController).not_to receive(:check_authorization)
            end
            perform action
          end
        end

      end # End several actions

    end # End except argument

  end # End skipping controller authorization




  #
  # Skip all authorizations checking
  #
  describe "skip_all_authorization" do
    #
    # The controller raiser error if grant enabled
    #
    before do
      class PostsController
        def index
          raise StrongBolt::Unauthorized if Grant::Status.grant_enabled?
        end
      end
    end
    after do
      class PostsController
        def index(); end
      end
    end

    it "should raise an error" do
      expect do
        get :index
      end.to raise_error StrongBolt::Unauthorized
    end

    context "when skipping" do
      before { PostsController.skip_all_authorization only: :index }
      after do
        PostsController.before_action :check_authorization
        PostsController.skip_around_action :disable_authorization
      end

      it "should not raise error" do
        expect do
          get :index
        end.not_to raise_error
      end
    end
  end # End skipping all authorization





  #
  # Mapping custom action to CRUD operation
  #
  describe "authorize_as_" do
    before do
      setup_session
      define_model "Post"
    end

    [:find, :update, :create, :destroy].each do |operation|
      context "authorize_as_#{operation}" do
        before do
          PostsController.send "authorize_as_#{operation}", :custom, :other
        end

        it "should respond_to" do
          expect(PostsController).to respond_to "authorize_as_#{operation}"
        end

        it "should call the proper operation" do
          expect(user).to receive(:can?).with(operation, Post).and_return true
          get :custom
        end

      end
    end
  end


end
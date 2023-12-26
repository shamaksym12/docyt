Rails.application.routes.draw do
  mount Rswag::Api::Engine => '/api-docs'
  scope '/reports/' do
    namespace :api do
      namespace :v1 do
        resources :advanced_reports, only: [:create]
        resources :reports, only: [:index, :show, :update, :destroy] do
          resources :report_users, only: [:create, :destroy]
          resources :items, only: [:update, :index, :show, :destroy] do
            collection do
              get :by_identifier
            end
          end
          resources :item_accounts, only: [:index] do
            collection do
              post :create_batch
              delete :destroy_batch
              post :copy_mapping
              post :load_default_mapping
            end
          end
          resources :item_values do
            collection do
              get :by_range
            end
          end
          resources :item_account_values do
            collection do
              get :by_range
            end
          end
          resources :report_datas do
            collection do
              get :by_range
              post :update_data
            end
          end
          resources :department_report_datas do
            collection do
              get :by_range
            end
          end
          member do
            post :update_report
          end
          collection do
            get :available_businesses
            get :by_template_id
            get :by_slug
            get :last_updated_date
          end
        end

        resources :report_datas do
          resources :item_values, only: [:show]
          resources :item_account_values do
            collection do
              get :by_item_and_column
              get :line_item_details
            end
          end
        end
        resources :items do
          collection do
            get :by_multi_business_report
          end
        end
        resources :multi_business_reports, only: [:create, :index, :show, :update, :destroy] do
          resources :multi_business_report_datas do
            collection do
              get :by_range
              put :update_daily_report_datas
            end
          end
          member do
            post :update_report
          end
          resources :multi_business_report_item_account_values do
            collection do
              get :item_account_values
            end
          end
        end
        resources :templates, only: [:index] do
          collection do
            get :all_templates
          end
        end
        resources :configurations, only: [:index]
        resources :standard_metrics, only: [:index]
        resources :budgets, only: [:create, :update, :index, :show, :destroy] do
          collection do
            get :by_ids
          end
          member do
            put :publish
            put :discard
          end
        end
        resources :budget_items, only: [:index] do
          collection do
            post :upsert
            post :auto_fill
          end
        end
        resources :report_services do
          collection do
            get :by_business_id
            put :update_default_budget
          end
        end
        namespace :quickbooks do
          resources :line_item_details do
            collection do
              get :by_period
            end
          end
          resources :unincluded_line_item_details do
            collection do
              get :by_period
            end
          end
        end
        resources :export_reports, only: [:create]
        resources :export_budgets, only: [:create]
        resources :import_budgets, only: [:create]
      end

      namespace :internal do
        resources :report_values, only: [:index]
      end
    end
  end
end

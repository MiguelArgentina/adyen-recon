# config/routes.rb
Rails.application.routes.draw do
  resources :report_files, only: %i[index show new create]
  resources :exports,      only: %i[index new create show] do
    member do
      get :download
    end
  end
  resource  :mapping_profile, only: %i[edit update]

  # Optional webhook (if you wire Adyen/SFTP notifier later)
  namespace :webhooks do
    resource :adyen_reports, only: :create
  end

  resources :reconciliations, only: [:index, :show] do
    collection do
      get  :by_key        # stable “natural key” show
      post :run           # rebuild a date range
    end
  end

  root "report_files#index"
end

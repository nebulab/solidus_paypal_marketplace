# frozen_string_literal: true

Spree::Core::Engine.routes.draw do
  post :paypal_webhooks, to: 'paypal_webhooks#create'
  namespace :admin do
    namespace :sellers do
      resources :prices, path: :offers
      resource :prices_import, only: [:create]
      resources :shipments, only: [:index, :edit, :update] do
        member do
          get :accept
          get :cancel
          get :reject
          get :ship
        end
        resources :line_items, only: [:update]
      end
      get :paypal_callbacks, to: 'paypal_callbacks#show'
      get :dashboard, to: 'dashboard#show'
    end

    resources :sellers do
      member do
        get :start_onboarding_process
      end
    end
  end
end

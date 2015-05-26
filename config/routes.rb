Api::Application.routes.draw do

  concern :restable do
    get 'track_activity', to: 'api#track_activity'
    post 'track_activity', to: 'api#track_activity'
    get 'core', to: 'api#core'
    get 'get_recommendations/(:count/(:algorithm))', to: 'api#get_recommendations'
    post 'delete_product', to: 'api#delete_product'
    get 'log_recommendation', to: 'api#log_recommendation'
    post 'log_recommendation', to: 'api#log_recommendation'
    get 'update_activity_user', to: 'api#update_activity_user'
    post 'delete_old_products', to: 'api#delete_old_products'
  end

  namespace :v1 do
    concerns :restable
    post 'add_product', to: 'api#add_product'     #v1 todo: deprecate this call
    post 'register_user', to: 'api#register_user' #v1 todo: deprecate this call
  end
  namespace :v2 do
    concerns :restable
    post 'product/:id', to: 'api#product'       #v2 doc
    post 'user/:id',    to: 'api#user'          #v2 doc
    get 'recommend',    to: 'api#recommend'
    post 'log_impression', to: 'api#log_impression'
    get 'log_impression', to: 'api#log_impression' # using get for ajax cross domain compatibility
  end

  devise_for :admins
  resources :clients
  resources :activities
  resources :users do
    get 'change_algorithm/:algorithm', to: 'users#change_algorithm', as: 'change_algorithm'
  end
  resources :products

  get '/recommend/(:external_id/(:count/(:algorithm)))', to: 'users#recommend', constraints: { :external_id => /[^\/]+/ }, as: 'recommend'

  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
  
  get 'environment', to: 'pages#environment', as: 'environment'
  root 'pages#index'

end

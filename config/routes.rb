Rails.application.routes.draw do
  # Liveness: 200 if the app booted without raising. Says nothing about the database.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Readiness: 200 only if the app can also reach PostgreSQL.
  get 'health' => 'health#show', as: :health_check

  resources :books, param: :serial_number, only: %i[index show create update destroy] do
    resources :borrowings, only: :create do
      post :return, on: :collection, to: 'returns#create'
    end
  end

  resources :readers, param: :card_number, only: %i[index show create]
end

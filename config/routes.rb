Rails.application.routes.draw do
  resources :products do
  end

  resource :cart, only:[:show, :destroy] do
    collection do
      post :add, path:'add/:id'
      get :mpg, path: 'checkout'
      post :notify
      post :return
    end
  end
end

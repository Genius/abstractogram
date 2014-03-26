Abstractogram::Application.routes.draw do
  root 'talks#index'
  get 'talks/query' => 'talks#query', as: :query
end

# frozen_string_literal: true

require 'sinatra'
require 'tilt/erubis'
require 'sinatra/content_for'
require 'pry'

require_relative 'database_persistance'

configure do
  enable :sessions
  set :session_secret, 'secret' # don't do this in a regular app

  set :erb, escape_html: true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_persistance.rb'
end

helpers do
  def complete?(list)
    list[:todos_count].positive? && list[:todos_remaining_count].zero?
  end

  def list_class(list)
    'complete' if complete?(list)
  end

  def todo_class(todo)
    'complete' if todo[:completed]
  end

  def sorted_lists(lists)
    complete_lists, incomplete_lists = lists.partition { |list| complete?(list) }

    incomplete_lists.each { |list| yield list, list[:id] }
    complete_lists.each { |list| yield list, list[:id] }
  end

  def sorted_todos(todos)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

# Load list and handle invalid ids
def load_list(id)
  list = @storage.find_list(id)

  return list if list

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

# Return error message if name is invalid. Return nil if name is valid.
def error_in_list_name(name)
  if !(1..100).cover?(name.size)
    'List name must be between 1 and 100 characters.'
  elsif @storage.lists.any? { |list| list[:name] == name }
    'List name must be unique'
  end
end

# Return error message if todo is invalid. Return nil if todo is valid.
def error_in_todo_name(name)
  error = 'Todo name must be between 1 and 100 characters.'
  error unless (1..100).cover?(name.size)
end

before do
  @storage = DatabasePersistance.new(logger)
end

before '/lists/:list_id/*' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
end

after do
  @storage.disconnect
end

get '/' do
  redirect '/lists'
end

# View all of the lists
get '/lists' do
  @lists = @storage.lists

  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_in_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_list(list_name)
    session[:success] = 'The list has been created.'

    redirect '/lists'
  end
end

# Display an individual list
get '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todos = @storage.find_list_todos(@list_id)

  erb :list, layout: :layout
end

# Edit am existing list
get '/lists/:list_id/edit' do
  erb :edit_list, layout: :layout
end

# Edit an existing list
post '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  list_name = params[:list_name].strip

  error = error_in_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@list_id, list_name)

    session[:success] = 'The list has been updated.'

    redirect "lists/#{@list_id}"
  end
end

# Delete an existing list
post '/lists/:list_id/destroy' do
  @storage.delete_list(@list_id)

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    session[:success] = 'The list has been deleted.'
    redirect '/lists'
  end
end

# Add a todo to a list
post '/lists/:list_id/todos' do
  todo_name = params[:todo].strip

  error = error_in_todo_name(todo_name)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_todo(@list_id, todo_name)

    session[:success] = 'The todo has been added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/destroy' do
  todo_id = params[:todo_id].to_i

  @storage.delete_todo(@list_id, todo_id)

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = 'Todo successfully deleted.'
    redirect "/lists/#{@list_id}"
  end
end

# Update status of todo in a list
post '/lists/:list_id/todos/:todo_id' do
  is_completed = params[:completed] == 'true'
  todo_id = params[:todo_id].to_i

  @storage.update_todo_status(@list_id, todo_id, is_completed)

  redirect "/lists/#{@list_id}"
end

# Complete all todos in a list
post '/lists/:id/complete_all' do
  @storage.mark_all_todos_completed(@list_id)

  session[:success] = 'All todos have been completed.'

  redirect "/lists/#{@list_id}"
end

not_found do
  redirect '/lists'
end

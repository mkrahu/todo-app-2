class SessionPersistance
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def lists
    @session[:lists]
  end

  def create_list(list_name)
    id = next_list_id
    lists << { id: id, name: list_name, todos: [] }
  end

  def delete_list(id)
    lists.delete_if { |list| list[:id] == id }
  end

  def find_list(id)
    lists.find { |list| list[:id] == id }
  end

  def update_list_name(list_id, list_name)
    list = find_list(list_id)
    list[:name] = list_name
  end

  def create_todo(list_id, todo_name)
    list = find_list(list_id)
    todo_id = next_todo_id(list_id)
    list[:todos] << { id: todo_id, name: todo_name, completed: false }
  end

  def delete_todo(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].delete_if { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, status)
    list = find_list(list_id)
    todo = list[:todos].find { |todo| todo[:id] == todo_id }
    todo[:completed] = status
  end

  def mark_all_todos_completed(list_id)
    list = find_list(list_id)

    list[:todos].each do |todo|
     todo[:completed] = true
    end
  end

  private

  def next_list_id
    max = lists.map { |list| list[:id] }.max || 0
    max + 1
  end

  def next_todo_id(list_id)
    list = find_list(list_id)
    max = list[:todos].map { |todo| todo[:id] }.max || 0
    max + 1
  end
end
